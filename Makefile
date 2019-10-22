drivers=sgp30 sgpc3 svm30
clean_drivers=$(foreach d, $(drivers), clean_$(d))
release_drivers=$(foreach d, $(drivers), release/$(d))

.PHONY: FORCE all $(release_drivers) $(clean_drivers) style-check style-fix

all: prepare $(drivers)

prepare: sgp-common/sgp_git_version.c

$(drivers): prepare
	cd $@ && $(MAKE) $(MFLAGS)

sgp-common/sgp_git_version.c: FORCE
	git describe --always --dirty | \
		awk 'BEGIN \
		{print "/* THIS FILE IS AUTOGENERATED */"} \
		{print "#include \"sgp_git_version.h\""} \
		{print "const char * SGP_DRV_VERSION_STR = \"" $$0"\";"} \
		END {}' > $@ || echo "Can't update version, not a git repository"

$(release_drivers): sgp-common/sgp_git_version.c
	export rel=$@ && \
	export driver=$${rel#release/} && \
	export tag="$$(git describe --always --dirty)" && \
	export pkgname="$${driver}-$${tag}" && \
	export pkgdir="release/$${pkgname}" && \
	rm -rf "$${pkgdir}" && mkdir -p "$${pkgdir}" && \
	cp -r embedded-common/* "$${pkgdir}" && \
	cp -r sgp-common/* "$${pkgdir}" && \
	cp -r $${driver}/* "$${pkgdir}" && \
	cp CHANGELOG.md LICENSE "$${pkgdir}" && \
	echo 'sensirion_common_dir = .' >> $${pkgdir}/user_config.inc && \
	echo 'sgp_common_dir = .' >> $${pkgdir}/user_config.inc && \
	echo "$${driver}_dir = ." >> $${pkgdir}/user_config.inc && \
	cd "$${pkgdir}" && $(MAKE) $(MFLAGS) && $(MAKE) clean $(MFLAGS) && cd - && \
	cd release && zip -r "$${pkgname}.zip" "$${pkgname}" && cd - && \
	ln -sf $${pkgname} $@

release/svm30: release/sgp30
	export rel=$@ && \
	export driver=$${rel#release/} && \
	export tag="$$(git describe --always --dirty)" && \
	export pkgname="$${driver}-$${tag}" && \
	export pkgdir="release/$${pkgname}" && \
	(cd ../embedded-sht && make prepare) && \
	cp -r release/sgp30/ $${pkgdir} && \
	cp -r ../embedded-sht/sht-common/* $${pkgdir} && \
	cp -r ../embedded-sht/shtc1/* $${pkgdir} && \
	cp svm30/Makefile $${pkgdir} && \
	cp svm30/*.[ch] $${pkgdir} && \
	cp svm30/default_config.inc $${pkgdir} && \
	for i in $${driver}_dir sgp_driver_dir sht_driver_dir sensirion_common_dir sgp_common_dir sht_common_dir sgp30_dir shtc1_dir; \
		do echo "$$i = ." >> $${pkgdir}/user_config.inc; \
	done && \
	cd "$${pkgdir}" && $(MAKE) $(MFLAGS) && $(MAKE) clean $(MFLAGS) && cd - && \
	cd release && zip -r "$${pkgname}.zip" "$${pkgname}" && cd - && \
	ln -sf $${pkgname} $@

release: clean $(release_drivers)

$(clean_drivers):
	export rel=$@ && \
	export driver=$${rel#clean_} && \
	cd $${driver} && $(MAKE) clean $(MFLAGS) && cd -

clean: $(clean_drivers)
	rm -rf release

style-fix:
	@if [ $$(git status --porcelain -uno 2> /dev/null | wc -l) -gt "0" ]; \
	then \
		echo "Refusing to run on dirty git state. Commit your changes first."; \
		exit 1; \
	fi; \
	git ls-files | grep -e '\.\(c\|h\|cpp\)$$' | xargs clang-format -i -style=file;

style-check: style-fix
	@if [ $$(git status --porcelain -uno 2> /dev/null | wc -l) -gt "0" ]; \
	then \
		echo "Style check failed:"; \
		git diff; \
		git checkout -f; \
		exit 1; \
	fi;
