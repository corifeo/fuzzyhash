from line_profiler import LineProfiler
import numpy as np
from fuzzyhash.hashing import CythonRollHash

A=CythonRollHash()
B=np.random.randint(0, 127, 1000, dtype='uint32')
C=A.rawhash(B)

profile = LineProfiler(A.modhash)
profile.runcall(A.modhash, B, 768)
profile.print_stats()
