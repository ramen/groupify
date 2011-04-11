(* groupify.ml - recursively set group ownership and setgid bit *)

open OptParse
open Printf
open Unix
open Unix.LargeFile

let version = "%prog 0.5 by ramen"
let verbose = ref false

let rec process group exclude dir =
  let get_gid name =
    try
      (getgrnam name).gr_gid
    with
      | Not_found ->
          printf "unknown group: %s\n" name;
          raise Exit in
    try
      (let gid = get_gid group in
       let exclude_gid = List.map get_gid exclude in
         match stat dir with
           | {st_kind=S_DIR; st_gid=dir_gid}
               when List.mem dir_gid exclude_gid ->
               printf "specified directory is excluded: %s\n" dir
           | {st_kind=S_DIR; st_uid=uid} ->
               alter_dir dir uid gid;
               process_dir gid exclude_gid dir
           | _ ->
               printf "not a directory: %s\n" dir)
    with
      | Unix_error(_, "stat", file) ->
          printf "error: unable to stat %s\n" file
      | Unix_error(_, "chmod", file) ->
          printf "error: unable to chmod %s\n" file
      | Unix_error(_, "chown", file) ->
          printf "error: unable to chown %s\n" file
      | Exit ->
          ()

and process_dir gid exclude_gid dir =
  try
    let dir_handle = opendir dir in
      Std.finally
        (fun () -> closedir dir_handle)
        (process_files gid exclude_gid dir) dir_handle
  with
    | Unix_error(_, "opendir", dir) ->
        printf "warning: unable to open directory %s\n" dir

and process_files gid exclude_gid dir dir_handle =
  try
    while true do
      try
        (match readdir dir_handle with
           | "."
           | ".." -> ()
           | file ->
               let path = sprintf "%s/%s" dir file in
               let stats = stat path in
                 (match stats with
                    | {st_gid=file_gid}
                        when List.mem file_gid exclude_gid -> ()
                    | {st_kind=S_REG; st_uid=uid} ->
                        (try
                           access path [X_OK];
                           alter_exec_file path uid gid
                         with Unix_error(EACCES, _, _) ->
                           alter_file path uid gid)
                    | {st_kind=S_DIR; st_uid=uid} ->
                        alter_dir path uid gid;
                        process_dir gid exclude_gid path
                    | _ -> ()))
      with
        | Unix_error(_, "stat", file) ->
            printf "warning: unable to stat %s\n" file
        | Unix_error(_, "chmod", file) ->
            printf "warning: unable to chmod %s\n" file
        | Unix_error(_, "chown", file) ->
            printf "warning: unable to chown %s\n" file
    done
  with End_of_file -> ()

and alter_file path uid gid =
  (if !verbose then printf "file: %s\n" path);
  chmod path 0o664;
  chown path uid gid

and alter_exec_file path uid gid =
  (if !verbose then printf "executable file: %s\n" path);
  chmod path 0o775;
  chown path uid gid

and alter_dir path uid gid =
  (if !verbose then printf "dir: %s\n" path);
  chmod path 0o2775;
  chown path uid gid

let main () =
  let opts =
    OptParser.make
      ~prog:        "groupify"
      ~usage:       "%prog [-v] [-e<group>]* <group> <dir>"
      ~description: "recursively set group ownership and setgid bit"
      ~version
      () in

  let verbose_opt = StdOpt.store_true () in
  let _ =
    OptParser.add
      opts
      ~short_name: 'v'
      ~help: "verbose"
      verbose_opt in

  let exclude = ref [] in
  let exclude_opt =
    StdOpt.str_callback
      ~metavar: "<group>"
      (fun s -> exclude := s :: !exclude) in
  let _ =
    OptParser.add
      opts
      ~short_name: 'e'
      ~help: "group(s) to exclude"
      exclude_opt in

  let args = OptParser.parse_argv opts in
    verbose := Opt.get verbose_opt;
    match args with
      | [group; dir] -> process group !exclude dir
      | _ -> OptParser.usage opts ()

let _ = main ()
