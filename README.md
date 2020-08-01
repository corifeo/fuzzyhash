# Installation (build cython modules)

python setup.py build_ext --inplace

# Usage
```
from fuzzyhash import FuzzyHashGenerate
fuzzy = FuzzyHashGenerate()
fuzzy.hash('The quick brown fox jumps over the lazy dog')
3:FJKKIUKact:FHIGi

fuzzy.hash_from_file("C:/windows/notepad.exe")
3072:4GPGNDPjlam62b+jJQQUQhLBiW+3mCzSJSrVrvkwuS4GvRepr:5GN70v2b+jJTh4WsmCz8SVrfvpK:"C:/windows/notepad.exe"
```
