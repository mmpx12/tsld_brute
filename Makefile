install:
	mkdir -p /usr/share/tsld
	cp TLD.txt TSLD.txt /usr/share/tsld/.
	install -m755 tsld_brute.sh /usr/bin/tsld_brute
clean:
	rm -rf /usr/share/tsld
	rm /usr/bin/tsld_brute
