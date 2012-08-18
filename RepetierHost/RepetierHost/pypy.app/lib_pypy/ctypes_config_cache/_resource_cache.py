try:
    from __pypy__ import cpumodel
except ImportError:
    from pypy.jit.backend import detect_cpu
    cpumodel = detect_cpu.autodetect_main_model_and_size()
# XXX relative import, should be removed together with
# XXX the relative imports done e.g. by lib_pypy/pypy_test/test_hashlib
mod = __import__("_resource_%s_" % (cpumodel,),
                 globals(), locals(), ["*"])
globals().update(mod.__dict__)
