# python setup.py build_ext --inplace
from distutils.core import setup 
from distutils.extension import Extension 
from Cython.Distutils import build_ext
from Cython.Build import cythonize
from numpy import get_include

___version___ = '0.1'


ext_modules = [
        Extension('fuzzyhash.modules.modulus', sources=['fuzzyhash/modules/modulus.pyx'], include_dirs=[get_include()], extra_compile_args=["/openmp"], extra_link_args=["/openmp"]),
        Extension('fuzzyhash.modules.sumhash', sources=['fuzzyhash/modules/sumhash.pyx'], include_dirs=[get_include()]),
        Extension('fuzzyhash.modules.rollhash', sources=['fuzzyhash/modules/rollhash.pyx'], include_dirs=[get_include()]),
] 

setup(name='python-fuzzyhash',
        author='Francesco Manzoni',
        version=___version___,
        description="Python extension computing fuzzy hashing, distances and similarities.",
        classifiers=["Programming Language :: Python"],
        keywords='ssdeep fuzzyhash spamsum levenshtein comparison',
        license='GPL',
        ext_modules = ext_modules,
        cmdclass = {'build_ext': build_ext},
      )