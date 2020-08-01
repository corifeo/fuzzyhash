
clean:
	rm -f -r fuzzyhash/build/
	rm -f fuzzyhash/modules/*.pyd

clean-c:
	rm -f fuzzyhash/modules/*.c

clean-all: clean clean-c

build: clean
	python setup.py build_ext --inplace

tests:
	python -m unittest discover -s tests/ -p 'test_*.py'
 