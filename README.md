Implementation of ssdeep / spamsum fuzzy hashing algorithm in python and few lines of cython, not as fast as original SSDeep C++ implementation but fast enough to process a malware samples folder in few seconds (throughput should be around 100MB/s, 100x faster than the pure python benchmark). All credit for the algorithm goes to the original author [PDF](https://www.dfrws.org/sites/default/files/session-files/paper-identifying_almost_identical_files_using_context_triggered_piecewise_hashing.pdf)


# Installation (build cython modules)

python setup.py build_ext --inplace

# Usage
```
from fuzzyhash import FuzzyHashGenerate
fuzzy = FuzzyHashGenerate()
```
```
fuzzy.hash('The quick brown fox jumps over the lazy dog')
3:FJKKIUKact:FHIGi
```
```
fuzzy.hash('The quick brown fox jumps over the lazy hog')
3:FJKKIUKacp:FHIGu
```
```
fuzzy.hash('The quick brown dog jumps over the lazy fox')
3:FJKm1SKacE:Fl1UL
```
```
fuzzy.hash_from_file("C:/windows/notepad.exe")
3072:4GPGNDPjlam62b+jJQQUQhLBiW+3mCzSJSrVrvkwuS4GvRepr:5GN70v2b+jJTh4WsmCz8SVrfvpK:"C:/windows/notepad.exe"
```


# TODO
- Hash comparison
- Command line helper
