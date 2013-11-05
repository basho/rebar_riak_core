DEST = $(HOME)/.rebar/templates

install: directory copy

directory:
	mkdir -p $(DEST)

copy:
	cp riak* $(DEST)
