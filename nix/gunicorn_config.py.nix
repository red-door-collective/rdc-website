{ listen, pythonpath }:
''
import multiprocessing

workers = multiprocessing.cpu_count() * 2 + 1
bind = "${listen}"

proc_name = "eviction-tracker"
pythonpath = "${pythonpath}"
''