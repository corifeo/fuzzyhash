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
from cpython.array cimport array, clone

@boundscheck(False)
@wraparound(False)
@cdivision(True)
cdef class CythonRollHash:
    DEF WINDOW_SIZE = 7
    DEF BYTE_SHIFT = 5
    cdef uint32_t rhash

    def hash(self, cnp.ndarray[uint32_t] iarray not None):
        # rewraps cython array into a numpy array, slight overhead
        return np.asarray(self._hash(iarray))

    def rawhash(self, cnp.ndarray[uint32_t, ndim=1] iarray not None):
        return self._hash(iarray)

    def modhash(self, cnp.ndarray[uint32_t, ndim=1] iarray not None, unsigned long modulo):
        return self._modhash(iarray, modulo)

    def lasthash(self):
        # return last calculated hash in memory
        return <uint32_t>self.rhash

    cdef _hash(self, cnp.ndarray[uint32_t, ndim=1] iarray):
        # initisalize spamsum variables and indexes
        cdef uint32_t xhash = 0, yhash = 0, zhash = 0, rhash = 0
        cdef unsigned long array_x = <unsigned long>iarray.shape[0]
        cdef unsigned long ws = <unsigned long>WINDOW_SIZE
        cdef unsigned long bs = <unsigned long>BYTE_SHIFT
        cdef unsigned long idx = 0, midx = 0
        # allocate memory for both window and results
        cdef uint32_t *window = <uint32_t*> malloc(sizeof(uint32_t) * ws)
        cdef uint32_t[::1] window_view = <uint32_t[:ws]> window
        cdef uint32_t[::1] iarray_view = iarray
        # allocate memory for results depending on modulo
        cdef uint32_t *results = <uint32_t *>malloc(sizeof(uint32_t) * array_x)
        cdef uint32_t[:] results_view = <uint32_t[:array_x]>results
        window_view[:] = 0
        for idx in range(array_x):
            yhash = yhash - xhash + (ws * iarray_view[idx])
            xhash = xhash + iarray_view[idx] - window_view[midx]
            zhash = (<unsigned long>zhash << bs) ^ iarray_view[idx]
            rhash = (xhash + yhash + zhash)
            window_view[midx] = iarray_view[idx]
            results_view[idx] = rhash
            # reset counter when midx hits 7, cheaper than using modulo on idx
            midx += 1
            if midx == ws:
                midx = 0
        self.rhash = rhash
        return np.asarray(results_view)

    cdef _modhash(self, cnp.ndarray[uint32_t, ndim=1] iarray, unsigned long modulo):
        # initisalize spamsum variables and indexes
        cdef uint32_t xhash = 0, yhash = 0, zhash = 0, rhash = 0
        cdef unsigned long array_x = <unsigned long>iarray.shape[0]
        cdef unsigned long ws = <unsigned long>WINDOW_SIZE
        cdef unsigned long bs = <unsigned long>BYTE_SHIFT        
        cdef unsigned long idx = 0, midx = 0
        # create a memoryview for input array
        cdef uint32_t[::1] iarray_view = iarray        
        # allocate memory for results depending on modulo
        cdef uint32_t *results = <uint32_t *>malloc(2*sizeof(uint32_t) * array_x)
        cdef uint32_t[:, :] results_view = <uint32_t[:array_x, :2]>results
        # allocate memory for window and initialize
        cdef uint32_t *window = <uint32_t*> malloc(sizeof(uint32_t) * ws)
        cdef uint32_t[::1] window_view = <uint32_t[:ws]> window
        window_view[:] = 0
        for idx in range(array_x):
                yhash = yhash - xhash + (ws * iarray_view[idx])
                xhash = xhash + iarray_view[idx] - window_view[midx]
                zhash = (<unsigned long>zhash << <unsigned long>bs) ^ <unsigned long>iarray_view[idx]
                rhash = (xhash + yhash + zhash)
                window_view[midx] = iarray_view[idx]
                #iarray_view[idx] = rhash
                ###
                results_view[idx,0] = self._true_modulo(rhash, modulo)
                results_view[idx,1] = self._true_modulo(rhash, modulo*2)
                # reset counter when midx hits 7, cheaper than using modulo on idx
                midx += 1
                if midx == ws:
                    midx = 0
        ## call modulus
        self.rhash = rhash
        return np.asarray(results_view)

    cdef uint32_t _true_modulo(self, unsigned long rhash, unsigned long modulo) nogil:
        return (rhash % modulo)