#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import io
import time
import math
import logging

import numpy as np
from string import ascii_lowercase, ascii_uppercase, digits
from fuzzyhash.modules.sumhash import CythonSumHash
from fuzzyhash.modules.rollhash import CythonRollHash
from fuzzyhash.modules.modulus import CythonModulus

MAX_DIGEST_LEN = 64
MIN_BLOCKSIZE = 3
HASH_INIT = 0x27
BUFFER_SIZE = 8096

logging.basicConfig(level=logging.DEBUG)

class FuzzyHashGenerate(object):
    def __init__(self, block_size=None, buffer_size=BUFFER_SIZE):
        """ Setup initial configuration and parameters """
        self._b64 = np.array([x for x in ascii_uppercase + ascii_lowercase + digits + '+/'], dtype=np.str)
        self._buffer_size = buffer_size or BUFFER_SIZE
        self._block_size = block_size or MIN_BLOCKSIZE
        self._timer = time.time()

    def _reset_cython_functions(self) -> None:
        """ Re-instantiate cython native functions """
        self.rollhash_context = CythonRollHash()
        self.sumhash_context = CythonSumHash()
        self.modulus_context = CythonModulus()

    def _reset_hashes_state(self) -> None:
        """ Resets three arrays containing results """
        self.long_hash = self.short_hash = self.last_hash = np.str()

    def hash(self, s):
        if not isinstance(s, str):
            raise FuzzyException('Input is not a valid string')
        return self.calc(io.BytesIO(s.encode()).getbuffer(), len(s))

    def hash_from_file(self, f):
        if not os.path.isfile(f):
            raise FuzzyException('File not found')
        if not os.access(f, os.R_OK):
            raise FuzzyException('File not readable')
        filesize = os.stat(f).st_size
        with io.open(f, 'rb', buffering=0) as buffer:
            h = self.calc(buffer.readall(), filesize)
        return '{}:"{}"'.format(h,f)

    def _ingest_buffer(self, buffer) -> np.ndarray:
        """ Validate input buffer and convert to numpy array """
        return np.frombuffer(buffer, dtype=np.ubyte).astype(np.uint32)

    def _guess_blocksize(self, stream_size) -> np.int:
        """ Simple implementation of initial blocksize calculation as per spamsum paper """
        return max(MIN_BLOCKSIZE, (MIN_BLOCKSIZE * 2 ** math.ceil(math.log((stream_size/(MAX_DIGEST_LEN*MIN_BLOCKSIZE)), 2))))

    def _enumerate_blocksize(self, n) -> np.array:
        """ Return a list of possible blocksize up to 2 power of N """
        return 3  *  2 ** np.arange(n)

    def _calc_rolling_hash(self, sequence) -> np.ndarray:
        """ Calculate rolling hash on the entire buffer """
        return np.array(self.rollhash_context.rawhash(sequence), dtype=np.uint32)

    def _calc_modulo_cython(self, rolling_hash, modulo) -> np.ndarray:
        """ Calculate modulo of rolling hashes """
        return np.array(self.modulus_context.rawmod(rolling_hash, modulo))

    def _calc_modulo_masks(self, modulo_hash):
        """ Calculate spamsum triggers and broadcasting list into array locations """
        self.rolling_hash_long = np.insert(np.argwhere(np.array(modulo_hash[:,0] == (self._block_size -1))).flatten()+1, 0, 0)
        self.rolling_hash_short = np.insert(np.argwhere(np.array(modulo_hash[:,1] == (2*self._block_size -1))).flatten()+1, 0, 0)
        self.long_mask = self.rolling_hash_long[np.arange(self.rolling_hash_long.size-1)[:, None] +np.arange(2)[None, :]]
        self.short_mask = self.rolling_hash_short[np.arange(self.rolling_hash_short.size-1)[:, None] +np.arange(2)[None, :]]
        
    def _calc_sum_hash(self):
        """ Calculating last chunks and sumhash of each individual segment """
        self.last_chunk_long = self.sumhash_context.hash(self.sequence[self.rolling_hash_long[-1]:len(self.sequence)])
        self.last_chunk_short = self.sumhash_context.hash(self.sequence[self.rolling_hash_short[-1]:len(self.sequence)])
        self.long_sum = np.append(np.array([self.sumhash_context.hash(self.sequence[x:y]) for x, y in self.long_mask]), self.last_chunk_long)
        self.short_sum = np.append(np.array([self.sumhash_context.hash(self.sequence[x:y]) for x, y in self.short_mask]), self.last_chunk_short)

    def _generate_signature(self):
        self.long_hash = ''.join([self._b64[x] for x in self.long_sum])
        self.short_hash = ''.join([self._b64[x] for x in self.short_sum])

    def calc(self, buffer, stream_size):
        try:
            logging.debug('Main function started')
            self._reset_hashes_state()
            self._reset_cython_functions()
            logging.debug('Main function initialized')
            self._block_size = self._guess_blocksize(stream_size)
            logging.debug('Guessed blocksize of {}'.format(self._block_size))
            self.sequence = self._ingest_buffer(buffer)
            logging.debug('Loaded {} bytes from buffer'.format(self.sequence.size))
            self.rolling_hash = self._calc_rolling_hash(self.sequence)
            self.modulo_hash = self._calc_modulo_cython(self.rolling_hash, self._block_size)
            logging.debug('Calculated rolling hash')
            self._calc_modulo_masks(self.modulo_hash)
            logging.debug('Calculated modulo masks') 
            self._calc_sum_hash()
            logging.debug('Calculated sum hash')
            self._generate_signature()
            logging.debug('Signature finished in {} seconds'.format(round(np.float(time.time()) - self._timer, 5)))
        except:
            raise FuzzyException()
        return '{}:{}:{}'.format(self._block_size, self.long_hash, self.short_hash)

class FuzzyHashCompare():
    pass

class FuzzyException(Exception):
    pass
