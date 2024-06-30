{ listen, pythonpath }:
''
  import multiprocessing
  import os
  from rdc_website.extensions import scheduler

  workers = multiprocessing.cpu_count() * 2 + 1
  bind = "${listen}"

  proc_name = "rdc_website"
  pythonpath = "${pythonpath}"
  timeout = 120
  statsd_host = "localhost:8125"
  user = "rdc_website"
  group = "red-door-collective"
  preload = True

  def on_starting(server):
      flask_app = server.app.wsgi()
      scheduler.api_enabled = True
      scheduler.init_app(flask_app)
      scheduler.start()

      from rdc_website import jobs 
''
