# cython: boundscheck=False, wraparound=False, nonecheck=False, language_level=3, py2_import=True, annotate=True
# -*- coding: utf-8 -*-

import numpy as np
cimport numpy as cnp
from numpy cimport ndarray, uint8_t, uint32_t, uint64_t
from cython import boundscheck, wraparound, cdivision, cmod
from cython.parallel import prange, parallel
from libc.stdlib cimport malloc, free

@boundscheck(False)
@wraparound(False)
@cdivision(True)
cdef class CythonModulus:
    def mod(self, cnp.ndarray[uint32_t] iarray not None, int modulo):
        return np.asarray(self._mod(iarray, modulo))

    def rawmod(self, cnp.ndarray[uint32_t] iarray not None, int modulo):
        return self._mod(iarray, modulo)

    cdef _mod(self, uint32_t[:] iarray, int modulo):
        cdef signed long array_x = <signed long>iarray.shape[0]
        cdef uint32_t[:] iarray_view = iarray
        cdef Py_ssize_t idx, i

        cdef uint32_t *results = <uint32_t *>malloc(2*sizeof(uint32_t) * array_x)
        cdef uint32_t[:, :] results_view = <uint32_t[:array_x, :2]>results

        for idx in prange(array_x, nogil=True, schedule='static'):
                results_view[idx,0] = self._true_modulo(iarray_view[idx], modulo)
                results_view[idx,1] = self._true_modulo(iarray_view[idx], (modulo*2))
        return results_view

    cdef uint32_t _shift_modulo(self, unsigned long rhash, unsigned long modulo) nogil:
        return (rhash & ((modulo//3)-1))
    
    cdef uint32_t _true_modulo(self, unsigned long rhash, unsigned long modulo) nogil:
        return (rhash % modulo)

    cdef uint32_t _reduce_modulo(self, unsigned long rhash, unsigned long modulo) nogil:
        return (<uint64_t> rhash * <uint64_t> modulo) >> 32