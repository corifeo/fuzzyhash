# python -m timeit -s "import numpy as np; import hashing; A=hashing.CythonRollHash(); B=np.random.randint(0, 127, 1000, dtype='uint32')" "C=A.calc(B)"
# python -m timeit -s "import numpy as np; import hashing; A=hashing.CythonRollHash(); B=np.random.randint(0, 127, 1000, dtype='uint32')" "C=A.modhash(B, 768)"
# python -m timeit -s "import numpy as np; import hashing; A=hashing.CythonModulus(); B=np.random.randint(0, 127, 1000, dtype='uint32')" "C=A.rawmod(B, 768)"

import os
import time
import unittest
import numpy as np

from fuzzyhash.modules.sumhash import CythonSumHash
from fuzzyhash.modules.rollhash import CythonRollHash
from fuzzyhash.modules.modulus import CythonModulus

unittest.TestLoader.sortTestMethodsUsing = None

class Test_CythonHashingRoll(unittest.TestCase):
        def setUp(self):
                self.array = np.array([ord(c) for c in 'The quick brown fox jumps over the lazy dog'], dtype=np.uint32)
                self._started_at = time.time()    

        def test_rollhash_class(self):
                obj = CythonRollHash()
                self.assertIsInstance(obj.hash(self.array), np.ndarray)

        def test_rollhash_random(self):
                obj = CythonRollHash()
                self.array = np.array(np.arange(1024*4), dtype=np.uint32)
                self.assertIsInstance(obj.hash(self.array), np.ndarray)

        def test_rollhash_text(self):
                obj = CythonRollHash()
                expect = np.array([756,4212,91485,2864215,91593359,2930907753,3594639358,3359205036])
                results = obj.hash(self.array)
                self.assertTrue(np.array(results[0:8] == expect).all())

        def test_rollhash_text_modulo(self):
                obj = CythonRollHash()
                expect = np.array([[0,0],[0,0],[0,3],[1,1],[2,5],[0,3],[1,4],[0,0]])
                results = obj.modhash(self.array, 3)
                self.assertTrue(np.array(results[0:8] == expect).all())

        def test_rollhash_rawhash(self):
                obj = CythonRollHash()
                expect = np.array([756,4212,91485,2864215,91593359,2930907753,3594639358,3359205036])
                results = obj.rawhash(self.array)
                self.assertTrue(np.array(results[0:8] == expect).all())
                
        def test_rollhash_lasthash(self):
                obj = CythonRollHash()
                results = obj.hash(self.array)
                self.assertEqual(obj.lasthash(), 3011619540)

        def test_rollhash_slow(self):
                obj = CythonRollHash()
                self.array = np.random.randint(0, 127, 1024*1024*4).astype('uint32')
                self.assertIsNotNone(obj.rawhash(self.array))

        def tearDown(self):
                with np.errstate(divide='ignore', invalid='ignore'):
                        elapsed = np.float(time.time() - self._started_at)
                        mbsize = np.float(np.divide(self.array.nbytes, 1024*1024))
                        mbsecond = np.divide(mbsize, elapsed)
                        mbsecond = 0 if np.isnan(mbsecond) or not np.isfinite(mbsecond) else mbsecond
                print('({}s {}MB/s) '.format(np.around(elapsed, 3), np.around(mbsecond, 3)), end='')

class Perf_CythonHashingSum(unittest.TestCase):  

        def setup(self, multiplier):
                self.obj = CythonSumHash()
                self.array = np.random.randint(0, 127, 1024*1024*multiplier).astype('uint32')
                self._started_at = time.time()  

        def test_should_run_fast(self):
                self.setup(8)
                self.assertIsInstance(self.obj.hash(self.array), int)

        def test_should_run_slow(self):
                self.setup(32)
                self.assertIsInstance(self.obj.hash(self.array), int)

        def test_should_run_slower(self):
                self.setup(128)
                self.assertIsInstance(self.obj.hash(self.array), int)

        def tearDown(self):
                with np.errstate(divide='ignore', invalid='ignore'):
                        elapsed = np.float(time.time() - self._started_at)
                        mbsize = np.float(np.divide(self.array.nbytes, 1024*1024))
                        mbsecond = np.divide(mbsize, elapsed)
                        mbsecond = 0 if np.isnan(mbsecond) or not np.isfinite(mbsecond) else mbsecond
                print('({}s {}MB/s) '.format(np.around(elapsed, 3), np.around(mbsecond, 3)), end='')

class Test_CythonHashingSum(unittest.TestCase):
        def setUp(self):
                obj = CythonRollHash()
                string = np.array([ord(c) for c in 'The quick brown fox jumps over the lazy dog'], dtype=np.uint32)
                self.array = obj.hash(string)
                self._started_at = time.time()     

        def test_sumhash_class(self):
                obj = CythonSumHash()
                self.array = np.array(np.arange(10000), dtype=np.uint32)
                self.assertIsInstance(obj.hash(self.array), int)

        def test_sumhash_text(self):
                obj = CythonSumHash()
                result = obj.hash(self.array)
                self.assertEqual(result, 41)

        def test_sumhash_text2(self):
                obj = CythonSumHash()
                self.array = np.array([ 84, 104, 101,  32, 113], dtype=np.uint32)
                result = obj.hash(self.array)
                self.assertEqual(result, 5)

        def test_sumhash_slow(self):
                obj = CythonSumHash()
                self.array = np.random.rand(1024*1024*8).astype('uint32')
                self.assertIsInstance(obj.hash(self.array), int)

        def test_sumhash_slower(self):
                obj = CythonSumHash()
                self.array = np.random.rand(1024*1024*32).astype('uint32')
                self.assertIsInstance(obj.hash(self.array), int)

        def tearDown(self):
                with np.errstate(divide='ignore', invalid='ignore'):
                        elapsed = np.float(time.time() - self._started_at)
                        mbsize = np.float(np.divide(self.array.nbytes, 1024*1024))
                        mbsecond = np.divide(mbsize, elapsed)
                        mbsecond = 0 if np.isnan(mbsecond) or not np.isfinite(mbsecond) else mbsecond
                print('({}s {}MB/s) '.format(np.around(elapsed, 3), np.around(mbsecond, 3)), end='')


class Perf_CythonHashingRoll(unittest.TestCase):  

        def setup(self, multiplier):
                self.obj = CythonRollHash()
                self.array = np.random.randint(0, 127, 1024*1024*multiplier).astype('uint32')
                self._started_at = time.time()  

        def test_should_run_fast(self):
                self.setup(8)
                self.assertIsInstance(self.obj.hash(self.array), np.ndarray)

        def test_should_run_faster(self):
                self.setup(8)
                self.assertIsNotNone(self.obj.rawhash(self.array))

        def test_rawhash_should_run_faster(self):
                self.setup(16)
                self.assertIsNotNone(self.obj.rawhash(self.array))

        def test_rawhash_should_run_fast(self):
                self.setup(64)
                self.assertIsNotNone(self.obj.rawhash(self.array))

        def test_modhash_large(self):
                self.setup(64)
                self.assertIsNotNone(self.obj.rawhash(self.array))

        def test_modhash_medium(self):
                self.setup(128)
                results = self.obj.modhash(self.array, 768)
                #print(results[0:10])
                self.assertIsNotNone(self.obj.modhash(self.array, 768))

        # def test_modhash2_medium(self):
        #         self.setup(32)
        #         results = self.obj.modhash2(self.array, 768)
        #         print(results[0:10])
        #         self.assertIsNotNone(results)

        # def test_modulus_slow(self):
        #         self.setup(32)
        #         self.assertIsNotNone(self.obj.hash(self.array, 768))

        # def test_modulus_slower(self):
        #         self.setup(64)
        #         self.assertIsNotNone(self.obj.hash(self.array, 3076))

        def tearDown(self):
                with np.errstate(divide='ignore', invalid='ignore'):
                        elapsed = np.float(time.time() - self._started_at)
                        mbsize = np.float(np.divide(self.array.nbytes, 1024*1024))
                        mbsecond = np.divide(mbsize, elapsed)
                        mbsecond = 0 if np.isnan(mbsecond) or not np.isfinite(mbsecond) else mbsecond
                print('({}s {}MB/s) '.format(np.around(elapsed, 3), np.around(mbsecond, 3)), end='')
        
class Perf_CythonModulus(unittest.TestCase):

        def setup(self, multiplier):
                self.obj = CythonModulus()
                self.array = np.random.randint(0, 1024*1024, 1024*1024*multiplier).astype('uint32')
                self._started_at = time.time()  

        def test_modulus_base(self):
                self.setup(1)
                self.array = np.array([756,4212,91485,2864215,91593359,2930907753,3594639358,3359205036], dtype=np.uint32)
                expect = np.array([[0,0],[0,0],[0,3],[1,1],[2,5],[0,3],[1,4],[0,0]])
                results = self.obj.mod(self.array, 3)
                self.assertTrue(np.array(results == expect).all())

        def test_modulus_works(self):
                self.setup(1)
                self.array = np.array([756,4212,91485,2864215,91593359,2930907753,3594639358,3359205036], dtype=np.uint32)
                expect = np.array([[0,0],[0,0],[0,3],[1,1],[2,5],[0,3],[1,4],[0,0]])
                results = self.obj.rawmod(self.array, 3)
                self.assertTrue(np.array(results == expect).all())

        # def test_modulus_works2(self):
        #         self.setup(1)
        #         self.array = np.array([756,4212,91485,2864215,91593359,2930907753,3594639358,3359205036], dtype=np.uint32)
        #         expect = np.array([0, 0, 0, 1, 2, 0, 1, 0])
        #         results = self.obj.rawmod2(self.array, 3)
        #         print(results)
        #         self.assertTrue(np.array(results == expect).all())

        def test_faster_than_numpy(self):
                self.setup(32)
                results = np.mod(self.array, 768)
                self.assertIsNotNone(results, np.ndarray)

        def test_rawmod_should_run_fast(self):
                self.setup(16)
                results = self.obj.rawmod(self.array, 768)
                self.assertIsNotNone(results)

        # def test_rawmod_should_run_faster(self):
        #         self.setup(16)
        #         results = self.obj.rawmod2(self.array, 768)
        #         self.assertIsNotNone(results)

        def test_mod_should_run_slow(self):
                self.setup(32)
                self.assertIsInstance(self.obj.mod(self.array, 768), np.ndarray)

        def tearDown(self):
                with np.errstate(divide='ignore', invalid='ignore'):
                        elapsed = np.float(time.time() - self._started_at)
                        mbsize = np.float(np.divide(self.array.nbytes, 1024*1024))
                        mbsecond = np.divide(mbsize, elapsed)
                        mbsecond = 0 if np.isnan(mbsecond) or not np.isfinite(mbsecond) else mbsecond
                print('({}s {}MB/s) '.format(np.around(elapsed, 3), np.around(mbsecond, 3)), end='')

if __name__ == '__main__':
    unittest.main()