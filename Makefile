VERSION = $(shell cat VERSION)
LIBRARY_PREFIX = pam_watchid
LIBRARY_NAME = $(LIBRARY_PREFIX).so
DESTINATION = /usr/local/lib/pam
PAM_FILE_BASE = /etc/pam.d/sudo
PAM_TEXT = auth sufficient $(LIBRARY_NAME)
PAM_TID_TEXT = auth       sufficient     pam_tid.so

all:
	swift build -c release --arch x86_64 --arch arm64
	mv .build/apple/Products/Release/libpam-watchid.dylib $(LIBRARY_NAME)

install: all
	sudo mkdir -p $(DESTINATION)
	sudo install -o root -g wheel -m 444 $(LIBRARY_NAME) $(DESTINATION)/$(LIBRARY_NAME).$(VERSION)

enable: install
ifeq (,$(wildcard $(PAM_FILE_BASE)_local.template))
	$(eval PAM_FILE = $(PAM_FILE_BASE))
# $(PAM_TEXT) is written to the second line of the file. This is under the assumption that the first line only is a descriptive comment about the file's contents, as is the default for macOS.
	grep $(LIBRARY_NAME) $(PAM_FILE) > /dev/null || sudo sed '2{h;s/.*/$(PAM_TEXT)/;p;g;}' $(PAM_FILE) | sudo tee $(PAM_FILE)
else
	$(eval PAM_FILE = $(PAM_FILE_BASE)_local)
# If the file is empty or doesn't exist, the full sudo_local.template is used as a base, otherwise, the existing file is used.
	sudo sh -c '[ -s $(PAM_FILE) ] || cat $(PAM_FILE).template >> $(PAM_FILE)'
# Modify sudo_local if the library isn't already present in the file
# Uncomment pam_tid.so
	grep $(LIBRARY_NAME) $(PAM_FILE) > /dev/null || sudo sed -i ".old" -e '/$(PAM_TID_TEXT)/s/^#//g' $(PAM_FILE)
# Insert $(PAM_TEXT) after the pam_tid.so line. This allows pam_tid.so to be used by default (which unexpectedly allows watch authentication as well) with pam_watchid.so as a fallback in cases where pam_tid.so falls through due to TouchID being deemed unavailable by macOS.
	grep $(LIBRARY_NAME) $(PAM_FILE) > /dev/null || sudo sed -i "" -e '/$(PAM_TID_TEXT)/s/$$/\nauth sufficient $(LIBRARY_NAME)/g' $(PAM_FILE)
endif
