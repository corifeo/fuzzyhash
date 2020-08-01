# python -m timeit -s "import numpy as np; import spamsum_legacy; A=spamsum_legacy.ssdeep_legacy(); B=np.random.randint(0, 127, 1000, dtype='uint32')" "C=A.slow_roll_hash(B)"
import os
import time
import unittest
import numpy as np
from fuzzyhash.spamsum import spamsum_legacy
from sys import getsizeof

class Test_SpamsumLegacy(unittest.TestCase):
        def setUp(self):
                self._started_at = time.time()        

        def tearDown(self):
                elapsed = time.time() - self._started_at
                print('{} ({}s)'.format(self.id(), round(elapsed, 5)))   

        def test_spamsum_string(self):
                obj = spamsum_legacy()
                string = 'The quick brown fox jumps over the lazy dog'
                result = '3:FJKKIUKact:FHIGi'
                self.assertEqual(obj.hash(string), result)

        def test_slow_roll_hash(self):
                obj = spamsum_legacy()
                array = np.array([ord(c) for c in 'The quick brown fox jumps over the lazy dog'], dtype=np.uint32)
                expect = np.array([756,4212,91485,2864215,91593359,2930907753,3594639358,3359205036])
                results = obj.slow_roll_hash(array)
                self.assertTrue(np.array(results[0:8] == expect[0:8]).all())


class Test_SpamsumBigFile(unittest.TestCase):
        def setUp(self):
                self.array = np.array(np.random.randint(0, 127, 1024 * 8), dtype=np.uint32)
                self._started_at = time.time()        

        def test_spamsum_bigfile(self):
                obj = spamsum_legacy()
                self.assertIsInstance(obj.hash_legacy(self.array), str)

        def tearDown(self):
                with np.errstate(divide='ignore', invalid='ignore'):
                        elapsed = np.float(time.time() - self._started_at)
                        mbsize = np.float(np.divide(self.array.nbytes, 1024*1024))
                        mbsecond = np.divide(mbsize, elapsed)
                        mbsecond = 0 if np.isnan(mbsecond) or not np.isfinite(mbsecond) else mbsecond
                print('({}s {}MB/s) '.format(np.around(elapsed, 3), np.around(mbsecond, 3)), end='')


if __name__ == '__main__':
    unittest.main()

# [84, 104, 101, 32, 113]
# result 3395507781
# Boolean mask array containing the triggers for long and short hashes
# https://stackoverflow.com/questions/40084931/taking-subarrays-from-numpy-array-with-given-stride-stepsize/40085052#40085052
# self.long_mask = np.argwhere(np.mod(self.rolling_hash, self.block_size) == (self.block_size -1)).flatten()+1
# self.short_mask = np.argwhere(np.mod(self.rolling_hash, 2*self.block_size) == (2*self.block_size -1)).flatten()+1
# # https://stackoverflow.com/questions/55451811/numpy-how-to-break-a-list-into-multiple-chunks/55452089#55452089
# self.long_hash = [self.b64[x] for x in np.mod([self.sum_hash(x) for x in np.split(self.sequence, self.long_mask)], 64)]
# self.short_hash = [self.b64[x] for x in np.mod([self.sum_hash(x) for x in np.split(self.sequence, self.short_mask)], 64)]

# a = ssdeep_legacy()
# b = ssdeep_legacy()
# print(a.hash_legacy('The quick brown fox jumps over the lazy dog'))
# #print(a.hash2('The quick brown fox jumps over the lazy hog'))
# # print(a.hash('The quick brown dog jumps over the lazy fox'))
# print(a.hash_legacy('Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.'))
# def broadcasting_app(a, L, S ):  # Window len = L, Stride len/stepsize = S
#     nrows = ((a.size-L)//S)+1
#     return a[S*np.arange(nrows)[:,None] + np.arange(L)]