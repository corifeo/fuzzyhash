#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Simple Python implementation without any optimisation primarily for performance comparison
"""
import os
import io
import numpy as np
from string import ascii_lowercase, ascii_uppercase, digits

MAX_DIGEST_LEN = 64
MIN_BLOCKSIZE = 3
ROLLING_WINDOW = 7
MAX_UINT32 = 0xFFFFFFFF
HASH_PRIME = 0x01000193
HASH_INIT = 0x28021967
BUFFER_SIZE = 64

class spamsum_legacy:
    def __init__(self):
        self.b64 = np.array([x for x in ascii_uppercase + ascii_lowercase + digits + '+/'], dtype=np.str)
        self._xhash = self._yhash = self._zhash = self._nhash = np.uint32()
        self._window = np.zeros(shape=ROLLING_WINDOW, dtype=np.uint32)
        self.long_hash = self.short_hash = np.str()

    def slow_roll_hash(self, array):
        results = np.zeros(shape=array.shape[0], dtype=np.uint32)
        for c in range(array.shape[0]):
            self._yhash = self._yhash - self._xhash + (ROLLING_WINDOW * array[c])
            self._xhash = self._xhash + array[c] - self._window[c % ROLLING_WINDOW]
            self._window[c % ROLLING_WINDOW] = array[c]
            self._zhash = (self._zhash << 5) ^ array[c]
            results[c] = (self._xhash + self._yhash + self._zhash) & MAX_UINT32
        return results

    def roll_hash(self, c: int) -> int:
        self._yhash = self._yhash - self._xhash + (ROLLING_WINDOW * c)
        self._xhash = self._xhash + c - self._window[self._nhash % ROLLING_WINDOW]
        self._window[self._nhash % ROLLING_WINDOW] = c
        self._nhash += 1
        self._zhash = (self._zhash << 5) ^ c
        return (self._xhash + self._yhash + self._zhash) & MAX_UINT32

    def fnv1_32(self, h: int, c: int) -> int:
        return np.uint32((h * HASH_PRIME) ^ c)

    def guess_blocksize(self, seq_len: int) -> int:
        block_size = MIN_BLOCKSIZE
        while block_size * MAX_DIGEST_LEN < seq_len:
            block_size *= 2
        return block_size

    def calc(self, stream, total_len):
        block_size = self.guess_blocksize(total_len)  
        block_hash1 = np.uint32(HASH_INIT)
        block_hash2 = np.uint32(HASH_INIT)
        roll_hash = np.uint32()
        while True:
            stream.seek(0)
            buffer = stream.read(BUFFER_SIZE)
            
            while buffer:
                for b in buffer:
                    block_hash1 = self.fnv1_32(block_hash1, b)
                    block_hash2 = self.fnv1_32(block_hash2, b)
                    roll_hash = self.roll_hash(b)
                    if (roll_hash % block_size) == (block_size - 1):
                        if len(self.long_hash) < (MAX_DIGEST_LEN - 1):
                            self.long_hash += self.b64[block_hash1 % 64]
                            block_hash1 = np.uint32(HASH_INIT)
                        if (roll_hash % (block_size * 2)) == ((block_size * 2) - 1):
                            if len(self.short_hash) < ((MAX_DIGEST_LEN // 2) - 1):
                                self.short_hash += self.b64[block_hash2 % 64]
                                block_hash2 = np.uint32(HASH_INIT)
                buffer = stream.read(BUFFER_SIZE)

            if block_size > MIN_BLOCKSIZE and len(self.long_hash) < (MAX_DIGEST_LEN // 2):
                block_size = (block_size // 2)
                block_hash1 = block_hash2 = np.uint32(HASH_INIT)
                roll_hash = np.uint32()
                self.long_hash = self.short_hash = np.str()
            else:
                roll_hash = (self._xhash + self._yhash + self._zhash) 
                if roll_hash != 0:
                    self.long_hash += self.b64[block_hash1 % 64]
                    self.short_hash += self.b64[block_hash2 % 64]
                break
        return '{0}:{1}:{2}'.format(block_size, self.long_hash, self.short_hash)


    def hash(self, s):
        if not isinstance(s, str):
            raise Exception('Input is not a valid string')
        return self.calc(io.BytesIO(s.encode()), len(s))

    def hash_legacy(self, s):
        return self.calc(io.BytesIO(s), len(s))

    def hash_from_file(self, f):
        if not os.path.isfile(f):
            raise Exception('File not found')
        if not os.access(f, os.R_OK):
            raise Exception('File not readable')
        filesize = os.stat(f).st_size
        h = self.calc(io.open(f, 'rb', buffering=0), filesize)
        return '{}:"{}"'.format(h,f)