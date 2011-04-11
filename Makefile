groupify : groupify.ml
	ocamlfind ocamlopt \
		-package extlib \
		-package unix \
		-linkpkg \
		-o groupify \
		groupify.ml

clean :
	rm -f *.cm? *.o groupify
