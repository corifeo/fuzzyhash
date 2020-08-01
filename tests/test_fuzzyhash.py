import os
import time
import string
import unittest
import numpy as np
from fuzzyhash.fuzzy import FuzzyHashGenerate

unittest.TestLoader.sortTestMethodsUsing = None

class Test_FuzzyHashingStrings(unittest.TestCase):

        def test_fuzzyhashing_class(self):
                obj = FuzzyHashGenerate()
                self.assertIsInstance(obj, FuzzyHashGenerate)   

        def test_fuzzyhashing_cython(self):
                obj = FuzzyHashGenerate()
                self.assertIsNone(obj._reset_cython_functions())   

        def test_fuzzyhashing_reset(self):
                obj = FuzzyHashGenerate()
                self.assertIsNone(obj._reset_hashes_state())   

        def test_fuzzyhashing_blocksize(self):
                obj = FuzzyHashGenerate()
                self.assertEqual(obj._guess_blocksize(1024*1024), 24576) 

        def test_fuzzyhashing_blocksize2(self):
                obj = FuzzyHashGenerate()
                self.assertEqual(obj._guess_blocksize(1610612736), 25165824) 

        def test_fuzzyhashing_enum_blocksize(self):
                obj = FuzzyHashGenerate()
                results = obj._enumerate_blocksize(30)
                self.assertIsNotNone(results) 

        def test_fuzzyhashing_min_blocksize(self):
                obj = FuzzyHashGenerate()
                self.assertEqual(obj._guess_blocksize(64), 3) 

        def test_fuzzyhashing_hash1(self):
                obj = FuzzyHashGenerate()
                string = 'The quick brown fox jumps over the lazy dog'
                self.assertEqual(obj.hash(string), '3:FJKKIUKact:FHIGi') 

        def test_fuzzyhashing_hash2(self):
                obj = FuzzyHashGenerate()
                string = 'The quick brown fox jumps over the lazy hog'
                self.assertEqual(obj.hash(string), '3:FJKKIUKacp:FHIGu') 

        def test_fuzzyhashing_hash3(self):
                obj = FuzzyHashGenerate()
                string = 'The quick brown dog jumps over the lazy hog'
                self.assertNotEqual(obj.hash(string), '3:FJKKIUKacn:FHIGn') 

        def test_fuzzyhashing_random_text(self):
                obj = FuzzyHashGenerate()
                array = ''.join([x for x in np.random.choice(list(string.ascii_letters), size=1024*64)])
                self.assertIsInstance(obj.hash(array), str) 

        def test_fuzzyhashing_random_longtext(self):
                obj = FuzzyHashGenerate()
                array = ''.join([x for x in np.random.choice(list(string.ascii_letters), size=1024*128)])
                self.assertIsInstance(obj.hash(array), str) 

class Test_FuzzyHashingFiles(unittest.TestCase):
        def setUp(self):
                # create a new 64MB file
                with open('output_file', 'wb') as file:
                        file.write(os.urandom(1024*1024*64))

        def test_fuzzyhashing_smallfile(self):
                obj = FuzzyHashGenerate()
                result = obj.hash_from_file('output_file')
                print(result)
                self.assertIsNotNone(result) 

if __name__ == '__main__':
    unittest.main()