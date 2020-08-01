# cython: boundscheck=False, wraparound=False, nonecheck=False, language_level=3, py2_import=True, annotate=True
# -*- coding: utf-8 -*-

"""
simple cython high-performance roll and sum hash implementation
python -m timeit -s "import numpy, hashing; A=hashing.CythonRollHash(); B=numpy.random.randint(0, 127, 1000, dtype='uint32')" "C=A.hash(B)"
python -m timeit -s "import numpy, hashing; A=hashing.CythonRollHash(); B=numpy.random.randint(0, 127, 1000, dtype='uint32')" "C=A.rawhash(B)"
"""
import time
import numpy as np
cimport numpy as cnp
from numpy cimport ndarray, uint8_t, uint32_t, uint64_t
from cython import boundscheck, wraparound, cdivision, cmod
from cython.parallel import prange, parallel
from libc.stdlib cimport malloc, free


@boundscheck(False)
@wraparound(False)
cdef class CythonSumHash:
    cdef uint32_t shash, sbyte, seed
    cdef int[64][64] sum_table

    def __cinit__(self, uint32_t seed=0x27):
        self.seed = seed
        self._load_table()

    def hash(self, cnp.ndarray[uint32_t, ndim=1] iarray) -> int:
        self._reset()
        return self._hash(iarray)

    def chash(self, cnp.ndarray[uint32_t] iarray):
        return self._hash(iarray)

    def step(self, uint32_t kbyte):
        self.shash = self._lookup(self.shash, kbyte)
        self.sbyte = kbyte
        return self.shash

    cdef int _lookup(self, int obyte,  int kbyte):
        return self.sum_table[<short>obyte][<short>kbyte & 0x3f]

    cdef void _reset(self):
        self.shash = self.seed
        self.sbyte = 0

    cdef _hash(self, cnp.ndarray[uint32_t] iarray):
        cdef unsigned long array_size = <unsigned long>iarray.shape[0]
        cdef unsigned long int idx = 0
        cdef uint32_t[:] iarray_view = iarray
        for idx in range(array_size):
            self.shash = self._lookup(self.shash, iarray_view[idx])
            self.sbyte = iarray_view[idx]
        return self.shash

    cdef void _load_table(self):
        self.sum_table = [[
            # Under GNU GPL2: https://github.com/ssdeep-project/ssdeep/blob/master/COPYING
            # source: https://github.com/ssdeep-project/ssdeep/blob/master/sum_table.h
            # 0x00
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
            0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
            0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f,
            0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f
            ], [
            # 0x01
            0x13, 0x12, 0x11, 0x10, 0x17, 0x16, 0x15, 0x14, 0x1b, 0x1a, 0x19, 0x18, 0x1f, 0x1e, 0x1d, 0x1c,
            0x03, 0x02, 0x01, 0x00, 0x07, 0x06, 0x05, 0x04, 0x0b, 0x0a, 0x09, 0x08, 0x0f, 0x0e, 0x0d, 0x0c,
            0x33, 0x32, 0x31, 0x30, 0x37, 0x36, 0x35, 0x34, 0x3b, 0x3a, 0x39, 0x38, 0x3f, 0x3e, 0x3d, 0x3c,
            0x23, 0x22, 0x21, 0x20, 0x27, 0x26, 0x25, 0x24, 0x2b, 0x2a, 0x29, 0x28, 0x2f, 0x2e, 0x2d, 0x2c,
            ], [
            # 0x02
            0x26, 0x27, 0x24, 0x25, 0x22, 0x23, 0x20, 0x21, 0x2e, 0x2f, 0x2c, 0x2d, 0x2a, 0x2b, 0x28, 0x29,
            0x36, 0x37, 0x34, 0x35, 0x32, 0x33, 0x30, 0x31, 0x3e, 0x3f, 0x3c, 0x3d, 0x3a, 0x3b, 0x38, 0x39,
            0x06, 0x07, 0x04, 0x05, 0x02, 0x03, 0x00, 0x01, 0x0e, 0x0f, 0x0c, 0x0d, 0x0a, 0x0b, 0x08, 0x09,
            0x16, 0x17, 0x14, 0x15, 0x12, 0x13, 0x10, 0x11, 0x1e, 0x1f, 0x1c, 0x1d, 0x1a, 0x1b, 0x18, 0x19,
            ], [
            # 0x03
            0x39, 0x38, 0x3b, 0x3a, 0x3d, 0x3c, 0x3f, 0x3e, 0x31, 0x30, 0x33, 0x32, 0x35, 0x34, 0x37, 0x36,
            0x29, 0x28, 0x2b, 0x2a, 0x2d, 0x2c, 0x2f, 0x2e, 0x21, 0x20, 0x23, 0x22, 0x25, 0x24, 0x27, 0x26,
            0x19, 0x18, 0x1b, 0x1a, 0x1d, 0x1c, 0x1f, 0x1e, 0x11, 0x10, 0x13, 0x12, 0x15, 0x14, 0x17, 0x16,
            0x09, 0x08, 0x0b, 0x0a, 0x0d, 0x0c, 0x0f, 0x0e, 0x01, 0x00, 0x03, 0x02, 0x05, 0x04, 0x07, 0x06,
            ], [
            # 0x04
            0x0c, 0x0d, 0x0e, 0x0f, 0x08, 0x09, 0x0a, 0x0b, 0x04, 0x05, 0x06, 0x07, 0x00, 0x01, 0x02, 0x03,
            0x1c, 0x1d, 0x1e, 0x1f, 0x18, 0x19, 0x1a, 0x1b, 0x14, 0x15, 0x16, 0x17, 0x10, 0x11, 0x12, 0x13,
            0x2c, 0x2d, 0x2e, 0x2f, 0x28, 0x29, 0x2a, 0x2b, 0x24, 0x25, 0x26, 0x27, 0x20, 0x21, 0x22, 0x23,
            0x3c, 0x3d, 0x3e, 0x3f, 0x38, 0x39, 0x3a, 0x3b, 0x34, 0x35, 0x36, 0x37, 0x30, 0x31, 0x32, 0x33,
            ], [
            # 0x05
            0x1f, 0x1e, 0x1d, 0x1c, 0x1b, 0x1a, 0x19, 0x18, 0x17, 0x16, 0x15, 0x14, 0x13, 0x12, 0x11, 0x10,
            0x0f, 0x0e, 0x0d, 0x0c, 0x0b, 0x0a, 0x09, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01, 0x00,
            0x3f, 0x3e, 0x3d, 0x3c, 0x3b, 0x3a, 0x39, 0x38, 0x37, 0x36, 0x35, 0x34, 0x33, 0x32, 0x31, 0x30,
            0x2f, 0x2e, 0x2d, 0x2c, 0x2b, 0x2a, 0x29, 0x28, 0x27, 0x26, 0x25, 0x24, 0x23, 0x22, 0x21, 0x20,
            ], [
            # 0x06
            0x32, 0x33, 0x30, 0x31, 0x36, 0x37, 0x34, 0x35, 0x3a, 0x3b, 0x38, 0x39, 0x3e, 0x3f, 0x3c, 0x3d,
            0x22, 0x23, 0x20, 0x21, 0x26, 0x27, 0x24, 0x25, 0x2a, 0x2b, 0x28, 0x29, 0x2e, 0x2f, 0x2c, 0x2d,
            0x12, 0x13, 0x10, 0x11, 0x16, 0x17, 0x14, 0x15, 0x1a, 0x1b, 0x18, 0x19, 0x1e, 0x1f, 0x1c, 0x1d,
            0x02, 0x03, 0x00, 0x01, 0x06, 0x07, 0x04, 0x05, 0x0a, 0x0b, 0x08, 0x09, 0x0e, 0x0f, 0x0c, 0x0d,
            ], [
            # 0x07
            0x05, 0x04, 0x07, 0x06, 0x01, 0x00, 0x03, 0x02, 0x0d, 0x0c, 0x0f, 0x0e, 0x09, 0x08, 0x0b, 0x0a,
            0x15, 0x14, 0x17, 0x16, 0x11, 0x10, 0x13, 0x12, 0x1d, 0x1c, 0x1f, 0x1e, 0x19, 0x18, 0x1b, 0x1a,
            0x25, 0x24, 0x27, 0x26, 0x21, 0x20, 0x23, 0x22, 0x2d, 0x2c, 0x2f, 0x2e, 0x29, 0x28, 0x2b, 0x2a,
            0x35, 0x34, 0x37, 0x36, 0x31, 0x30, 0x33, 0x32, 0x3d, 0x3c, 0x3f, 0x3e, 0x39, 0x38, 0x3b, 0x3a,
            ], [
            # 0x08
            0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
            0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
            0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
            0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
            ], [
            # 0x09
            0x2b, 0x2a, 0x29, 0x28, 0x2f, 0x2e, 0x2d, 0x2c, 0x23, 0x22, 0x21, 0x20, 0x27, 0x26, 0x25, 0x24,
            0x3b, 0x3a, 0x39, 0x38, 0x3f, 0x3e, 0x3d, 0x3c, 0x33, 0x32, 0x31, 0x30, 0x37, 0x36, 0x35, 0x34,
            0x0b, 0x0a, 0x09, 0x08, 0x0f, 0x0e, 0x0d, 0x0c, 0x03, 0x02, 0x01, 0x00, 0x07, 0x06, 0x05, 0x04,
            0x1b, 0x1a, 0x19, 0x18, 0x1f, 0x1e, 0x1d, 0x1c, 0x13, 0x12, 0x11, 0x10, 0x17, 0x16, 0x15, 0x14,
            ], [
            # 0x0a
            0x3e, 0x3f, 0x3c, 0x3d, 0x3a, 0x3b, 0x38, 0x39, 0x36, 0x37, 0x34, 0x35, 0x32, 0x33, 0x30, 0x31,
            0x2e, 0x2f, 0x2c, 0x2d, 0x2a, 0x2b, 0x28, 0x29, 0x26, 0x27, 0x24, 0x25, 0x22, 0x23, 0x20, 0x21,
            0x1e, 0x1f, 0x1c, 0x1d, 0x1a, 0x1b, 0x18, 0x19, 0x16, 0x17, 0x14, 0x15, 0x12, 0x13, 0x10, 0x11,
            0x0e, 0x0f, 0x0c, 0x0d, 0x0a, 0x0b, 0x08, 0x09, 0x06, 0x07, 0x04, 0x05, 0x02, 0x03, 0x00, 0x01,
            ], [
            # 0x0b
            0x11, 0x10, 0x13, 0x12, 0x15, 0x14, 0x17, 0x16, 0x19, 0x18, 0x1b, 0x1a, 0x1d, 0x1c, 0x1f, 0x1e,
            0x01, 0x00, 0x03, 0x02, 0x05, 0x04, 0x07, 0x06, 0x09, 0x08, 0x0b, 0x0a, 0x0d, 0x0c, 0x0f, 0x0e,
            0x31, 0x30, 0x33, 0x32, 0x35, 0x34, 0x37, 0x36, 0x39, 0x38, 0x3b, 0x3a, 0x3d, 0x3c, 0x3f, 0x3e,
            0x21, 0x20, 0x23, 0x22, 0x25, 0x24, 0x27, 0x26, 0x29, 0x28, 0x2b, 0x2a, 0x2d, 0x2c, 0x2f, 0x2e,
            ], [
            # 0x0c
            0x24, 0x25, 0x26, 0x27, 0x20, 0x21, 0x22, 0x23, 0x2c, 0x2d, 0x2e, 0x2f, 0x28, 0x29, 0x2a, 0x2b,
            0x34, 0x35, 0x36, 0x37, 0x30, 0x31, 0x32, 0x33, 0x3c, 0x3d, 0x3e, 0x3f, 0x38, 0x39, 0x3a, 0x3b,
            0x04, 0x05, 0x06, 0x07, 0x00, 0x01, 0x02, 0x03, 0x0c, 0x0d, 0x0e, 0x0f, 0x08, 0x09, 0x0a, 0x0b,
            0x14, 0x15, 0x16, 0x17, 0x10, 0x11, 0x12, 0x13, 0x1c, 0x1d, 0x1e, 0x1f, 0x18, 0x19, 0x1a, 0x1b,
            ], [
            # 0x0d
            0x37, 0x36, 0x35, 0x34, 0x33, 0x32, 0x31, 0x30, 0x3f, 0x3e, 0x3d, 0x3c, 0x3b, 0x3a, 0x39, 0x38,
            0x27, 0x26, 0x25, 0x24, 0x23, 0x22, 0x21, 0x20, 0x2f, 0x2e, 0x2d, 0x2c, 0x2b, 0x2a, 0x29, 0x28,
            0x17, 0x16, 0x15, 0x14, 0x13, 0x12, 0x11, 0x10, 0x1f, 0x1e, 0x1d, 0x1c, 0x1b, 0x1a, 0x19, 0x18,
            0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01, 0x00, 0x0f, 0x0e, 0x0d, 0x0c, 0x0b, 0x0a, 0x09, 0x08,
            ], [
            # 0x0e
            0x0a, 0x0b, 0x08, 0x09, 0x0e, 0x0f, 0x0c, 0x0d, 0x02, 0x03, 0x00, 0x01, 0x06, 0x07, 0x04, 0x05,
            0x1a, 0x1b, 0x18, 0x19, 0x1e, 0x1f, 0x1c, 0x1d, 0x12, 0x13, 0x10, 0x11, 0x16, 0x17, 0x14, 0x15,
            0x2a, 0x2b, 0x28, 0x29, 0x2e, 0x2f, 0x2c, 0x2d, 0x22, 0x23, 0x20, 0x21, 0x26, 0x27, 0x24, 0x25,
            0x3a, 0x3b, 0x38, 0x39, 0x3e, 0x3f, 0x3c, 0x3d, 0x32, 0x33, 0x30, 0x31, 0x36, 0x37, 0x34, 0x35,
            ], [
            # 0x0f
            0x1d, 0x1c, 0x1f, 0x1e, 0x19, 0x18, 0x1b, 0x1a, 0x15, 0x14, 0x17, 0x16, 0x11, 0x10, 0x13, 0x12,
            0x0d, 0x0c, 0x0f, 0x0e, 0x09, 0x08, 0x0b, 0x0a, 0x05, 0x04, 0x07, 0x06, 0x01, 0x00, 0x03, 0x02,
            0x3d, 0x3c, 0x3f, 0x3e, 0x39, 0x38, 0x3b, 0x3a, 0x35, 0x34, 0x37, 0x36, 0x31, 0x30, 0x33, 0x32,
            0x2d, 0x2c, 0x2f, 0x2e, 0x29, 0x28, 0x2b, 0x2a, 0x25, 0x24, 0x27, 0x26, 0x21, 0x20, 0x23, 0x22,
            ], [
            # 0x10
            0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f,
            0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f,
            0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
            ], [
            # 0x11
            0x03, 0x02, 0x01, 0x00, 0x07, 0x06, 0x05, 0x04, 0x0b, 0x0a, 0x09, 0x08, 0x0f, 0x0e, 0x0d, 0x0c,
            0x13, 0x12, 0x11, 0x10, 0x17, 0x16, 0x15, 0x14, 0x1b, 0x1a, 0x19, 0x18, 0x1f, 0x1e, 0x1d, 0x1c,
            0x23, 0x22, 0x21, 0x20, 0x27, 0x26, 0x25, 0x24, 0x2b, 0x2a, 0x29, 0x28, 0x2f, 0x2e, 0x2d, 0x2c,
            0x33, 0x32, 0x31, 0x30, 0x37, 0x36, 0x35, 0x34, 0x3b, 0x3a, 0x39, 0x38, 0x3f, 0x3e, 0x3d, 0x3c,
            ], [
            # 0x12
            0x16, 0x17, 0x14, 0x15, 0x12, 0x13, 0x10, 0x11, 0x1e, 0x1f, 0x1c, 0x1d, 0x1a, 0x1b, 0x18, 0x19,
            0x06, 0x07, 0x04, 0x05, 0x02, 0x03, 0x00, 0x01, 0x0e, 0x0f, 0x0c, 0x0d, 0x0a, 0x0b, 0x08, 0x09,
            0x36, 0x37, 0x34, 0x35, 0x32, 0x33, 0x30, 0x31, 0x3e, 0x3f, 0x3c, 0x3d, 0x3a, 0x3b, 0x38, 0x39,
            0x26, 0x27, 0x24, 0x25, 0x22, 0x23, 0x20, 0x21, 0x2e, 0x2f, 0x2c, 0x2d, 0x2a, 0x2b, 0x28, 0x29,
            ], [
            # 0x13
            0x29, 0x28, 0x2b, 0x2a, 0x2d, 0x2c, 0x2f, 0x2e, 0x21, 0x20, 0x23, 0x22, 0x25, 0x24, 0x27, 0x26,
            0x39, 0x38, 0x3b, 0x3a, 0x3d, 0x3c, 0x3f, 0x3e, 0x31, 0x30, 0x33, 0x32, 0x35, 0x34, 0x37, 0x36,
            0x09, 0x08, 0x0b, 0x0a, 0x0d, 0x0c, 0x0f, 0x0e, 0x01, 0x00, 0x03, 0x02, 0x05, 0x04, 0x07, 0x06,
            0x19, 0x18, 0x1b, 0x1a, 0x1d, 0x1c, 0x1f, 0x1e, 0x11, 0x10, 0x13, 0x12, 0x15, 0x14, 0x17, 0x16,
            ], [
            # 0x14
            0x3c, 0x3d, 0x3e, 0x3f, 0x38, 0x39, 0x3a, 0x3b, 0x34, 0x35, 0x36, 0x37, 0x30, 0x31, 0x32, 0x33,
            0x2c, 0x2d, 0x2e, 0x2f, 0x28, 0x29, 0x2a, 0x2b, 0x24, 0x25, 0x26, 0x27, 0x20, 0x21, 0x22, 0x23,
            0x1c, 0x1d, 0x1e, 0x1f, 0x18, 0x19, 0x1a, 0x1b, 0x14, 0x15, 0x16, 0x17, 0x10, 0x11, 0x12, 0x13,
            0x0c, 0x0d, 0x0e, 0x0f, 0x08, 0x09, 0x0a, 0x0b, 0x04, 0x05, 0x06, 0x07, 0x00, 0x01, 0x02, 0x03,
            ], [
            # 0x15
            0x0f, 0x0e, 0x0d, 0x0c, 0x0b, 0x0a, 0x09, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01, 0x00,
            0x1f, 0x1e, 0x1d, 0x1c, 0x1b, 0x1a, 0x19, 0x18, 0x17, 0x16, 0x15, 0x14, 0x13, 0x12, 0x11, 0x10,
            0x2f, 0x2e, 0x2d, 0x2c, 0x2b, 0x2a, 0x29, 0x28, 0x27, 0x26, 0x25, 0x24, 0x23, 0x22, 0x21, 0x20,
            0x3f, 0x3e, 0x3d, 0x3c, 0x3b, 0x3a, 0x39, 0x38, 0x37, 0x36, 0x35, 0x34, 0x33, 0x32, 0x31, 0x30,
            ], [
            # 0x16
            0x22, 0x23, 0x20, 0x21, 0x26, 0x27, 0x24, 0x25, 0x2a, 0x2b, 0x28, 0x29, 0x2e, 0x2f, 0x2c, 0x2d,
            0x32, 0x33, 0x30, 0x31, 0x36, 0x37, 0x34, 0x35, 0x3a, 0x3b, 0x38, 0x39, 0x3e, 0x3f, 0x3c, 0x3d,
            0x02, 0x03, 0x00, 0x01, 0x06, 0x07, 0x04, 0x05, 0x0a, 0x0b, 0x08, 0x09, 0x0e, 0x0f, 0x0c, 0x0d,
            0x12, 0x13, 0x10, 0x11, 0x16, 0x17, 0x14, 0x15, 0x1a, 0x1b, 0x18, 0x19, 0x1e, 0x1f, 0x1c, 0x1d,
            ], [
            # 0x17
            0x35, 0x34, 0x37, 0x36, 0x31, 0x30, 0x33, 0x32, 0x3d, 0x3c, 0x3f, 0x3e, 0x39, 0x38, 0x3b, 0x3a,
            0x25, 0x24, 0x27, 0x26, 0x21, 0x20, 0x23, 0x22, 0x2d, 0x2c, 0x2f, 0x2e, 0x29, 0x28, 0x2b, 0x2a,
            0x15, 0x14, 0x17, 0x16, 0x11, 0x10, 0x13, 0x12, 0x1d, 0x1c, 0x1f, 0x1e, 0x19, 0x18, 0x1b, 0x1a,
            0x05, 0x04, 0x07, 0x06, 0x01, 0x00, 0x03, 0x02, 0x0d, 0x0c, 0x0f, 0x0e, 0x09, 0x08, 0x0b, 0x0a,
            ], [
            # 0x18
            0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
            0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
            0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
            0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
            ], [
            # 0x19
            0x1b, 0x1a, 0x19, 0x18, 0x1f, 0x1e, 0x1d, 0x1c, 0x13, 0x12, 0x11, 0x10, 0x17, 0x16, 0x15, 0x14,
            0x0b, 0x0a, 0x09, 0x08, 0x0f, 0x0e, 0x0d, 0x0c, 0x03, 0x02, 0x01, 0x00, 0x07, 0x06, 0x05, 0x04,
            0x3b, 0x3a, 0x39, 0x38, 0x3f, 0x3e, 0x3d, 0x3c, 0x33, 0x32, 0x31, 0x30, 0x37, 0x36, 0x35, 0x34,
            0x2b, 0x2a, 0x29, 0x28, 0x2f, 0x2e, 0x2d, 0x2c, 0x23, 0x22, 0x21, 0x20, 0x27, 0x26, 0x25, 0x24,
            ], [
            # 0x1a
            0x2e, 0x2f, 0x2c, 0x2d, 0x2a, 0x2b, 0x28, 0x29, 0x26, 0x27, 0x24, 0x25, 0x22, 0x23, 0x20, 0x21,
            0x3e, 0x3f, 0x3c, 0x3d, 0x3a, 0x3b, 0x38, 0x39, 0x36, 0x37, 0x34, 0x35, 0x32, 0x33, 0x30, 0x31,
            0x0e, 0x0f, 0x0c, 0x0d, 0x0a, 0x0b, 0x08, 0x09, 0x06, 0x07, 0x04, 0x05, 0x02, 0x03, 0x00, 0x01,
            0x1e, 0x1f, 0x1c, 0x1d, 0x1a, 0x1b, 0x18, 0x19, 0x16, 0x17, 0x14, 0x15, 0x12, 0x13, 0x10, 0x11,
            ], [
            # 0x1b
            0x01, 0x00, 0x03, 0x02, 0x05, 0x04, 0x07, 0x06, 0x09, 0x08, 0x0b, 0x0a, 0x0d, 0x0c, 0x0f, 0x0e,
            0x11, 0x10, 0x13, 0x12, 0x15, 0x14, 0x17, 0x16, 0x19, 0x18, 0x1b, 0x1a, 0x1d, 0x1c, 0x1f, 0x1e,
            0x21, 0x20, 0x23, 0x22, 0x25, 0x24, 0x27, 0x26, 0x29, 0x28, 0x2b, 0x2a, 0x2d, 0x2c, 0x2f, 0x2e,
            0x31, 0x30, 0x33, 0x32, 0x35, 0x34, 0x37, 0x36, 0x39, 0x38, 0x3b, 0x3a, 0x3d, 0x3c, 0x3f, 0x3e,
            ], [
            # 0x1c
            0x14, 0x15, 0x16, 0x17, 0x10, 0x11, 0x12, 0x13, 0x1c, 0x1d, 0x1e, 0x1f, 0x18, 0x19, 0x1a, 0x1b,
            0x04, 0x05, 0x06, 0x07, 0x00, 0x01, 0x02, 0x03, 0x0c, 0x0d, 0x0e, 0x0f, 0x08, 0x09, 0x0a, 0x0b,
            0x34, 0x35, 0x36, 0x37, 0x30, 0x31, 0x32, 0x33, 0x3c, 0x3d, 0x3e, 0x3f, 0x38, 0x39, 0x3a, 0x3b,
            0x24, 0x25, 0x26, 0x27, 0x20, 0x21, 0x22, 0x23, 0x2c, 0x2d, 0x2e, 0x2f, 0x28, 0x29, 0x2a, 0x2b,
            ], [
            # 0x1d
            0x27, 0x26, 0x25, 0x24, 0x23, 0x22, 0x21, 0x20, 0x2f, 0x2e, 0x2d, 0x2c, 0x2b, 0x2a, 0x29, 0x28,
            0x37, 0x36, 0x35, 0x34, 0x33, 0x32, 0x31, 0x30, 0x3f, 0x3e, 0x3d, 0x3c, 0x3b, 0x3a, 0x39, 0x38,
            0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01, 0x00, 0x0f, 0x0e, 0x0d, 0x0c, 0x0b, 0x0a, 0x09, 0x08,
            0x17, 0x16, 0x15, 0x14, 0x13, 0x12, 0x11, 0x10, 0x1f, 0x1e, 0x1d, 0x1c, 0x1b, 0x1a, 0x19, 0x18,
            ], [
            # 0x1e
            0x3a, 0x3b, 0x38, 0x39, 0x3e, 0x3f, 0x3c, 0x3d, 0x32, 0x33, 0x30, 0x31, 0x36, 0x37, 0x34, 0x35,
            0x2a, 0x2b, 0x28, 0x29, 0x2e, 0x2f, 0x2c, 0x2d, 0x22, 0x23, 0x20, 0x21, 0x26, 0x27, 0x24, 0x25,
            0x1a, 0x1b, 0x18, 0x19, 0x1e, 0x1f, 0x1c, 0x1d, 0x12, 0x13, 0x10, 0x11, 0x16, 0x17, 0x14, 0x15,
            0x0a, 0x0b, 0x08, 0x09, 0x0e, 0x0f, 0x0c, 0x0d, 0x02, 0x03, 0x00, 0x01, 0x06, 0x07, 0x04, 0x05,
            ], [
            # 0x1f
            0x0d, 0x0c, 0x0f, 0x0e, 0x09, 0x08, 0x0b, 0x0a, 0x05, 0x04, 0x07, 0x06, 0x01, 0x00, 0x03, 0x02,
            0x1d, 0x1c, 0x1f, 0x1e, 0x19, 0x18, 0x1b, 0x1a, 0x15, 0x14, 0x17, 0x16, 0x11, 0x10, 0x13, 0x12,
            0x2d, 0x2c, 0x2f, 0x2e, 0x29, 0x28, 0x2b, 0x2a, 0x25, 0x24, 0x27, 0x26, 0x21, 0x20, 0x23, 0x22,
            0x3d, 0x3c, 0x3f, 0x3e, 0x39, 0x38, 0x3b, 0x3a, 0x35, 0x34, 0x37, 0x36, 0x31, 0x30, 0x33, 0x32,
            ], [
            # 0x20
            0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f,
            0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f,
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
            0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
            ], [
            # 0x21
            0x33, 0x32, 0x31, 0x30, 0x37, 0x36, 0x35, 0x34, 0x3b, 0x3a, 0x39, 0x38, 0x3f, 0x3e, 0x3d, 0x3c,
            0x23, 0x22, 0x21, 0x20, 0x27, 0x26, 0x25, 0x24, 0x2b, 0x2a, 0x29, 0x28, 0x2f, 0x2e, 0x2d, 0x2c,
            0x13, 0x12, 0x11, 0x10, 0x17, 0x16, 0x15, 0x14, 0x1b, 0x1a, 0x19, 0x18, 0x1f, 0x1e, 0x1d, 0x1c,
            0x03, 0x02, 0x01, 0x00, 0x07, 0x06, 0x05, 0x04, 0x0b, 0x0a, 0x09, 0x08, 0x0f, 0x0e, 0x0d, 0x0c,
            ], [
            # 0x22
            0x06, 0x07, 0x04, 0x05, 0x02, 0x03, 0x00, 0x01, 0x0e, 0x0f, 0x0c, 0x0d, 0x0a, 0x0b, 0x08, 0x09,
            0x16, 0x17, 0x14, 0x15, 0x12, 0x13, 0x10, 0x11, 0x1e, 0x1f, 0x1c, 0x1d, 0x1a, 0x1b, 0x18, 0x19,
            0x26, 0x27, 0x24, 0x25, 0x22, 0x23, 0x20, 0x21, 0x2e, 0x2f, 0x2c, 0x2d, 0x2a, 0x2b, 0x28, 0x29,
            0x36, 0x37, 0x34, 0x35, 0x32, 0x33, 0x30, 0x31, 0x3e, 0x3f, 0x3c, 0x3d, 0x3a, 0x3b, 0x38, 0x39,
            ], [
            # 0x23
            0x19, 0x18, 0x1b, 0x1a, 0x1d, 0x1c, 0x1f, 0x1e, 0x11, 0x10, 0x13, 0x12, 0x15, 0x14, 0x17, 0x16,
            0x09, 0x08, 0x0b, 0x0a, 0x0d, 0x0c, 0x0f, 0x0e, 0x01, 0x00, 0x03, 0x02, 0x05, 0x04, 0x07, 0x06,
            0x39, 0x38, 0x3b, 0x3a, 0x3d, 0x3c, 0x3f, 0x3e, 0x31, 0x30, 0x33, 0x32, 0x35, 0x34, 0x37, 0x36,
            0x29, 0x28, 0x2b, 0x2a, 0x2d, 0x2c, 0x2f, 0x2e, 0x21, 0x20, 0x23, 0x22, 0x25, 0x24, 0x27, 0x26,
            ], [
            # 0x24
            0x2c, 0x2d, 0x2e, 0x2f, 0x28, 0x29, 0x2a, 0x2b, 0x24, 0x25, 0x26, 0x27, 0x20, 0x21, 0x22, 0x23,
            0x3c, 0x3d, 0x3e, 0x3f, 0x38, 0x39, 0x3a, 0x3b, 0x34, 0x35, 0x36, 0x37, 0x30, 0x31, 0x32, 0x33,
            0x0c, 0x0d, 0x0e, 0x0f, 0x08, 0x09, 0x0a, 0x0b, 0x04, 0x05, 0x06, 0x07, 0x00, 0x01, 0x02, 0x03,
            0x1c, 0x1d, 0x1e, 0x1f, 0x18, 0x19, 0x1a, 0x1b, 0x14, 0x15, 0x16, 0x17, 0x10, 0x11, 0x12, 0x13,
            ], [
            # 0x25
            0x3f, 0x3e, 0x3d, 0x3c, 0x3b, 0x3a, 0x39, 0x38, 0x37, 0x36, 0x35, 0x34, 0x33, 0x32, 0x31, 0x30,
            0x2f, 0x2e, 0x2d, 0x2c, 0x2b, 0x2a, 0x29, 0x28, 0x27, 0x26, 0x25, 0x24, 0x23, 0x22, 0x21, 0x20,
            0x1f, 0x1e, 0x1d, 0x1c, 0x1b, 0x1a, 0x19, 0x18, 0x17, 0x16, 0x15, 0x14, 0x13, 0x12, 0x11, 0x10,
            0x0f, 0x0e, 0x0d, 0x0c, 0x0b, 0x0a, 0x09, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01, 0x00,
            ], [
            # 0x26
            0x12, 0x13, 0x10, 0x11, 0x16, 0x17, 0x14, 0x15, 0x1a, 0x1b, 0x18, 0x19, 0x1e, 0x1f, 0x1c, 0x1d,
            0x02, 0x03, 0x00, 0x01, 0x06, 0x07, 0x04, 0x05, 0x0a, 0x0b, 0x08, 0x09, 0x0e, 0x0f, 0x0c, 0x0d,
            0x32, 0x33, 0x30, 0x31, 0x36, 0x37, 0x34, 0x35, 0x3a, 0x3b, 0x38, 0x39, 0x3e, 0x3f, 0x3c, 0x3d,
            0x22, 0x23, 0x20, 0x21, 0x26, 0x27, 0x24, 0x25, 0x2a, 0x2b, 0x28, 0x29, 0x2e, 0x2f, 0x2c, 0x2d,
            ], [
            # 0x27
            0x25, 0x24, 0x27, 0x26, 0x21, 0x20, 0x23, 0x22, 0x2d, 0x2c, 0x2f, 0x2e, 0x29, 0x28, 0x2b, 0x2a,
            0x35, 0x34, 0x37, 0x36, 0x31, 0x30, 0x33, 0x32, 0x3d, 0x3c, 0x3f, 0x3e, 0x39, 0x38, 0x3b, 0x3a,
            0x05, 0x04, 0x07, 0x06, 0x01, 0x00, 0x03, 0x02, 0x0d, 0x0c, 0x0f, 0x0e, 0x09, 0x08, 0x0b, 0x0a,
            0x15, 0x14, 0x17, 0x16, 0x11, 0x10, 0x13, 0x12, 0x1d, 0x1c, 0x1f, 0x1e, 0x19, 0x18, 0x1b, 0x1a,
            ], [
            # 0x28
            0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
            0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
            0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
            0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
            ], [
            # 0x29
            0x0b, 0x0a, 0x09, 0x08, 0x0f, 0x0e, 0x0d, 0x0c, 0x03, 0x02, 0x01, 0x00, 0x07, 0x06, 0x05, 0x04,
            0x1b, 0x1a, 0x19, 0x18, 0x1f, 0x1e, 0x1d, 0x1c, 0x13, 0x12, 0x11, 0x10, 0x17, 0x16, 0x15, 0x14,
            0x2b, 0x2a, 0x29, 0x28, 0x2f, 0x2e, 0x2d, 0x2c, 0x23, 0x22, 0x21, 0x20, 0x27, 0x26, 0x25, 0x24,
            0x3b, 0x3a, 0x39, 0x38, 0x3f, 0x3e, 0x3d, 0x3c, 0x33, 0x32, 0x31, 0x30, 0x37, 0x36, 0x35, 0x34,
            ], [
            # 0x2a
            0x1e, 0x1f, 0x1c, 0x1d, 0x1a, 0x1b, 0x18, 0x19, 0x16, 0x17, 0x14, 0x15, 0x12, 0x13, 0x10, 0x11,
            0x0e, 0x0f, 0x0c, 0x0d, 0x0a, 0x0b, 0x08, 0x09, 0x06, 0x07, 0x04, 0x05, 0x02, 0x03, 0x00, 0x01,
            0x3e, 0x3f, 0x3c, 0x3d, 0x3a, 0x3b, 0x38, 0x39, 0x36, 0x37, 0x34, 0x35, 0x32, 0x33, 0x30, 0x31,
            0x2e, 0x2f, 0x2c, 0x2d, 0x2a, 0x2b, 0x28, 0x29, 0x26, 0x27, 0x24, 0x25, 0x22, 0x23, 0x20, 0x21,
            ], [
            # 0x2b
            0x31, 0x30, 0x33, 0x32, 0x35, 0x34, 0x37, 0x36, 0x39, 0x38, 0x3b, 0x3a, 0x3d, 0x3c, 0x3f, 0x3e,
            0x21, 0x20, 0x23, 0x22, 0x25, 0x24, 0x27, 0x26, 0x29, 0x28, 0x2b, 0x2a, 0x2d, 0x2c, 0x2f, 0x2e,
            0x11, 0x10, 0x13, 0x12, 0x15, 0x14, 0x17, 0x16, 0x19, 0x18, 0x1b, 0x1a, 0x1d, 0x1c, 0x1f, 0x1e,
            0x01, 0x00, 0x03, 0x02, 0x05, 0x04, 0x07, 0x06, 0x09, 0x08, 0x0b, 0x0a, 0x0d, 0x0c, 0x0f, 0x0e,
            ], [
            # 0x2c
            0x04, 0x05, 0x06, 0x07, 0x00, 0x01, 0x02, 0x03, 0x0c, 0x0d, 0x0e, 0x0f, 0x08, 0x09, 0x0a, 0x0b,
            0x14, 0x15, 0x16, 0x17, 0x10, 0x11, 0x12, 0x13, 0x1c, 0x1d, 0x1e, 0x1f, 0x18, 0x19, 0x1a, 0x1b,
            0x24, 0x25, 0x26, 0x27, 0x20, 0x21, 0x22, 0x23, 0x2c, 0x2d, 0x2e, 0x2f, 0x28, 0x29, 0x2a, 0x2b,
            0x34, 0x35, 0x36, 0x37, 0x30, 0x31, 0x32, 0x33, 0x3c, 0x3d, 0x3e, 0x3f, 0x38, 0x39, 0x3a, 0x3b,
            ], [
            # 0x2d
            0x17, 0x16, 0x15, 0x14, 0x13, 0x12, 0x11, 0x10, 0x1f, 0x1e, 0x1d, 0x1c, 0x1b, 0x1a, 0x19, 0x18,
            0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01, 0x00, 0x0f, 0x0e, 0x0d, 0x0c, 0x0b, 0x0a, 0x09, 0x08,
            0x37, 0x36, 0x35, 0x34, 0x33, 0x32, 0x31, 0x30, 0x3f, 0x3e, 0x3d, 0x3c, 0x3b, 0x3a, 0x39, 0x38,
            0x27, 0x26, 0x25, 0x24, 0x23, 0x22, 0x21, 0x20, 0x2f, 0x2e, 0x2d, 0x2c, 0x2b, 0x2a, 0x29, 0x28,
            ], [
            # 0x2e
            0x2a, 0x2b, 0x28, 0x29, 0x2e, 0x2f, 0x2c, 0x2d, 0x22, 0x23, 0x20, 0x21, 0x26, 0x27, 0x24, 0x25,
            0x3a, 0x3b, 0x38, 0x39, 0x3e, 0x3f, 0x3c, 0x3d, 0x32, 0x33, 0x30, 0x31, 0x36, 0x37, 0x34, 0x35,
            0x0a, 0x0b, 0x08, 0x09, 0x0e, 0x0f, 0x0c, 0x0d, 0x02, 0x03, 0x00, 0x01, 0x06, 0x07, 0x04, 0x05,
            0x1a, 0x1b, 0x18, 0x19, 0x1e, 0x1f, 0x1c, 0x1d, 0x12, 0x13, 0x10, 0x11, 0x16, 0x17, 0x14, 0x15,
            ], [
            # 0x2f
            0x3d, 0x3c, 0x3f, 0x3e, 0x39, 0x38, 0x3b, 0x3a, 0x35, 0x34, 0x37, 0x36, 0x31, 0x30, 0x33, 0x32,
            0x2d, 0x2c, 0x2f, 0x2e, 0x29, 0x28, 0x2b, 0x2a, 0x25, 0x24, 0x27, 0x26, 0x21, 0x20, 0x23, 0x22,
            0x1d, 0x1c, 0x1f, 0x1e, 0x19, 0x18, 0x1b, 0x1a, 0x15, 0x14, 0x17, 0x16, 0x11, 0x10, 0x13, 0x12,
            0x0d, 0x0c, 0x0f, 0x0e, 0x09, 0x08, 0x0b, 0x0a, 0x05, 0x04, 0x07, 0x06, 0x01, 0x00, 0x03, 0x02,
            ], [
            # 0x30
            0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
            0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f,
            0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f,
            ], [
            # 0x31
            0x23, 0x22, 0x21, 0x20, 0x27, 0x26, 0x25, 0x24, 0x2b, 0x2a, 0x29, 0x28, 0x2f, 0x2e, 0x2d, 0x2c,
            0x33, 0x32, 0x31, 0x30, 0x37, 0x36, 0x35, 0x34, 0x3b, 0x3a, 0x39, 0x38, 0x3f, 0x3e, 0x3d, 0x3c,
            0x03, 0x02, 0x01, 0x00, 0x07, 0x06, 0x05, 0x04, 0x0b, 0x0a, 0x09, 0x08, 0x0f, 0x0e, 0x0d, 0x0c,
            0x13, 0x12, 0x11, 0x10, 0x17, 0x16, 0x15, 0x14, 0x1b, 0x1a, 0x19, 0x18, 0x1f, 0x1e, 0x1d, 0x1c,
            ], [
            # 0x32
            0x36, 0x37, 0x34, 0x35, 0x32, 0x33, 0x30, 0x31, 0x3e, 0x3f, 0x3c, 0x3d, 0x3a, 0x3b, 0x38, 0x39,
            0x26, 0x27, 0x24, 0x25, 0x22, 0x23, 0x20, 0x21, 0x2e, 0x2f, 0x2c, 0x2d, 0x2a, 0x2b, 0x28, 0x29,
            0x16, 0x17, 0x14, 0x15, 0x12, 0x13, 0x10, 0x11, 0x1e, 0x1f, 0x1c, 0x1d, 0x1a, 0x1b, 0x18, 0x19,
            0x06, 0x07, 0x04, 0x05, 0x02, 0x03, 0x00, 0x01, 0x0e, 0x0f, 0x0c, 0x0d, 0x0a, 0x0b, 0x08, 0x09,
            ], [
            # 0x33
            0x09, 0x08, 0x0b, 0x0a, 0x0d, 0x0c, 0x0f, 0x0e, 0x01, 0x00, 0x03, 0x02, 0x05, 0x04, 0x07, 0x06,
            0x19, 0x18, 0x1b, 0x1a, 0x1d, 0x1c, 0x1f, 0x1e, 0x11, 0x10, 0x13, 0x12, 0x15, 0x14, 0x17, 0x16,
            0x29, 0x28, 0x2b, 0x2a, 0x2d, 0x2c, 0x2f, 0x2e, 0x21, 0x20, 0x23, 0x22, 0x25, 0x24, 0x27, 0x26,
            0x39, 0x38, 0x3b, 0x3a, 0x3d, 0x3c, 0x3f, 0x3e, 0x31, 0x30, 0x33, 0x32, 0x35, 0x34, 0x37, 0x36,
            ], [
            # 0x34
            0x1c, 0x1d, 0x1e, 0x1f, 0x18, 0x19, 0x1a, 0x1b, 0x14, 0x15, 0x16, 0x17, 0x10, 0x11, 0x12, 0x13,
            0x0c, 0x0d, 0x0e, 0x0f, 0x08, 0x09, 0x0a, 0x0b, 0x04, 0x05, 0x06, 0x07, 0x00, 0x01, 0x02, 0x03,
            0x3c, 0x3d, 0x3e, 0x3f, 0x38, 0x39, 0x3a, 0x3b, 0x34, 0x35, 0x36, 0x37, 0x30, 0x31, 0x32, 0x33,
            0x2c, 0x2d, 0x2e, 0x2f, 0x28, 0x29, 0x2a, 0x2b, 0x24, 0x25, 0x26, 0x27, 0x20, 0x21, 0x22, 0x23,
            ], [
            # 0x35
            0x2f, 0x2e, 0x2d, 0x2c, 0x2b, 0x2a, 0x29, 0x28, 0x27, 0x26, 0x25, 0x24, 0x23, 0x22, 0x21, 0x20,
            0x3f, 0x3e, 0x3d, 0x3c, 0x3b, 0x3a, 0x39, 0x38, 0x37, 0x36, 0x35, 0x34, 0x33, 0x32, 0x31, 0x30,
            0x0f, 0x0e, 0x0d, 0x0c, 0x0b, 0x0a, 0x09, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01, 0x00,
            0x1f, 0x1e, 0x1d, 0x1c, 0x1b, 0x1a, 0x19, 0x18, 0x17, 0x16, 0x15, 0x14, 0x13, 0x12, 0x11, 0x10,
            ], [
            # 0x36
            0x02, 0x03, 0x00, 0x01, 0x06, 0x07, 0x04, 0x05, 0x0a, 0x0b, 0x08, 0x09, 0x0e, 0x0f, 0x0c, 0x0d,
            0x12, 0x13, 0x10, 0x11, 0x16, 0x17, 0x14, 0x15, 0x1a, 0x1b, 0x18, 0x19, 0x1e, 0x1f, 0x1c, 0x1d,
            0x22, 0x23, 0x20, 0x21, 0x26, 0x27, 0x24, 0x25, 0x2a, 0x2b, 0x28, 0x29, 0x2e, 0x2f, 0x2c, 0x2d,
            0x32, 0x33, 0x30, 0x31, 0x36, 0x37, 0x34, 0x35, 0x3a, 0x3b, 0x38, 0x39, 0x3e, 0x3f, 0x3c, 0x3d,
            ], [
            # 0x37
            0x15, 0x14, 0x17, 0x16, 0x11, 0x10, 0x13, 0x12, 0x1d, 0x1c, 0x1f, 0x1e, 0x19, 0x18, 0x1b, 0x1a,
            0x05, 0x04, 0x07, 0x06, 0x01, 0x00, 0x03, 0x02, 0x0d, 0x0c, 0x0f, 0x0e, 0x09, 0x08, 0x0b, 0x0a,
            0x35, 0x34, 0x37, 0x36, 0x31, 0x30, 0x33, 0x32, 0x3d, 0x3c, 0x3f, 0x3e, 0x39, 0x38, 0x3b, 0x3a,
            0x25, 0x24, 0x27, 0x26, 0x21, 0x20, 0x23, 0x22, 0x2d, 0x2c, 0x2f, 0x2e, 0x29, 0x28, 0x2b, 0x2a,
            ], [
            # 0x38
            0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
            0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
            0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
            0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
            ], [
            # 0x39
            0x3b, 0x3a, 0x39, 0x38, 0x3f, 0x3e, 0x3d, 0x3c, 0x33, 0x32, 0x31, 0x30, 0x37, 0x36, 0x35, 0x34,
            0x2b, 0x2a, 0x29, 0x28, 0x2f, 0x2e, 0x2d, 0x2c, 0x23, 0x22, 0x21, 0x20, 0x27, 0x26, 0x25, 0x24,
            0x1b, 0x1a, 0x19, 0x18, 0x1f, 0x1e, 0x1d, 0x1c, 0x13, 0x12, 0x11, 0x10, 0x17, 0x16, 0x15, 0x14,
            0x0b, 0x0a, 0x09, 0x08, 0x0f, 0x0e, 0x0d, 0x0c, 0x03, 0x02, 0x01, 0x00, 0x07, 0x06, 0x05, 0x04,
            ], [
            # 0x3a
            0x0e, 0x0f, 0x0c, 0x0d, 0x0a, 0x0b, 0x08, 0x09, 0x06, 0x07, 0x04, 0x05, 0x02, 0x03, 0x00, 0x01,
            0x1e, 0x1f, 0x1c, 0x1d, 0x1a, 0x1b, 0x18, 0x19, 0x16, 0x17, 0x14, 0x15, 0x12, 0x13, 0x10, 0x11,
            0x2e, 0x2f, 0x2c, 0x2d, 0x2a, 0x2b, 0x28, 0x29, 0x26, 0x27, 0x24, 0x25, 0x22, 0x23, 0x20, 0x21,
            0x3e, 0x3f, 0x3c, 0x3d, 0x3a, 0x3b, 0x38, 0x39, 0x36, 0x37, 0x34, 0x35, 0x32, 0x33, 0x30, 0x31,
            ], [
            # 0x3b
            0x21, 0x20, 0x23, 0x22, 0x25, 0x24, 0x27, 0x26, 0x29, 0x28, 0x2b, 0x2a, 0x2d, 0x2c, 0x2f, 0x2e,
            0x31, 0x30, 0x33, 0x32, 0x35, 0x34, 0x37, 0x36, 0x39, 0x38, 0x3b, 0x3a, 0x3d, 0x3c, 0x3f, 0x3e,
            0x01, 0x00, 0x03, 0x02, 0x05, 0x04, 0x07, 0x06, 0x09, 0x08, 0x0b, 0x0a, 0x0d, 0x0c, 0x0f, 0x0e,
            0x11, 0x10, 0x13, 0x12, 0x15, 0x14, 0x17, 0x16, 0x19, 0x18, 0x1b, 0x1a, 0x1d, 0x1c, 0x1f, 0x1e,
            ], [
            # 0x3c
            0x34, 0x35, 0x36, 0x37, 0x30, 0x31, 0x32, 0x33, 0x3c, 0x3d, 0x3e, 0x3f, 0x38, 0x39, 0x3a, 0x3b,
            0x24, 0x25, 0x26, 0x27, 0x20, 0x21, 0x22, 0x23, 0x2c, 0x2d, 0x2e, 0x2f, 0x28, 0x29, 0x2a, 0x2b,
            0x14, 0x15, 0x16, 0x17, 0x10, 0x11, 0x12, 0x13, 0x1c, 0x1d, 0x1e, 0x1f, 0x18, 0x19, 0x1a, 0x1b,
            0x04, 0x05, 0x06, 0x07, 0x00, 0x01, 0x02, 0x03, 0x0c, 0x0d, 0x0e, 0x0f, 0x08, 0x09, 0x0a, 0x0b,
            ], [
            # 0x3d
            0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01, 0x00, 0x0f, 0x0e, 0x0d, 0x0c, 0x0b, 0x0a, 0x09, 0x08,
            0x17, 0x16, 0x15, 0x14, 0x13, 0x12, 0x11, 0x10, 0x1f, 0x1e, 0x1d, 0x1c, 0x1b, 0x1a, 0x19, 0x18,
            0x27, 0x26, 0x25, 0x24, 0x23, 0x22, 0x21, 0x20, 0x2f, 0x2e, 0x2d, 0x2c, 0x2b, 0x2a, 0x29, 0x28,
            0x37, 0x36, 0x35, 0x34, 0x33, 0x32, 0x31, 0x30, 0x3f, 0x3e, 0x3d, 0x3c, 0x3b, 0x3a, 0x39, 0x38,
            ], [
            # 0x3e
            0x1a, 0x1b, 0x18, 0x19, 0x1e, 0x1f, 0x1c, 0x1d, 0x12, 0x13, 0x10, 0x11, 0x16, 0x17, 0x14, 0x15,
            0x0a, 0x0b, 0x08, 0x09, 0x0e, 0x0f, 0x0c, 0x0d, 0x02, 0x03, 0x00, 0x01, 0x06, 0x07, 0x04, 0x05,
            0x3a, 0x3b, 0x38, 0x39, 0x3e, 0x3f, 0x3c, 0x3d, 0x32, 0x33, 0x30, 0x31, 0x36, 0x37, 0x34, 0x35,
            0x2a, 0x2b, 0x28, 0x29, 0x2e, 0x2f, 0x2c, 0x2d, 0x22, 0x23, 0x20, 0x21, 0x26, 0x27, 0x24, 0x25,
            ], [
            # 0x3f
            0x2d, 0x2c, 0x2f, 0x2e, 0x29, 0x28, 0x2b, 0x2a, 0x25, 0x24, 0x27, 0x26, 0x21, 0x20, 0x23, 0x22,
            0x3d, 0x3c, 0x3f, 0x3e, 0x39, 0x38, 0x3b, 0x3a, 0x35, 0x34, 0x37, 0x36, 0x31, 0x30, 0x33, 0x32,
            0x0d, 0x0c, 0x0f, 0x0e, 0x09, 0x08, 0x0b, 0x0a, 0x05, 0x04, 0x07, 0x06, 0x01, 0x00, 0x03, 0x02,
            0x1d, 0x1c, 0x1f, 0x1e, 0x19, 0x18, 0x1b, 0x1a, 0x15, 0x14, 0x17, 0x16, 0x11, 0x10, 0x13, 0x12,
        ]]