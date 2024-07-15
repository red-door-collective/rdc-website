{
  listen,
  pythonpath,
}: ''
  import multiprocessing
  import os
  from rdc_website.extensions import scheduler
  from prometheus_flask_exporter.multiprocess import GunicornPrometheusMetrics

  workers = multiprocessing.cpu_count() * 2 + 1
  bind = "${listen}"

  proc_name = "rdc_website"
  pythonpath = "${pythonpath}"
  timeout = 120
  user = "rdc_website"
  group = "red_door_collective"
  preload = True

  def on_starting(server):
      flask_app = server.app.wsgi()
      scheduler.api_enabled = True
      scheduler.init_app(flask_app)
      scheduler.start()

      from rdc_website import jobs

  def when_ready(server):
    GunicornPrometheusMetrics.start_http_server_when_ready(int(os.getenv('METRICS_PORT')))

  def child_exit(server, worker):
    GunicornPrometheusMetrics.mark_process_dead_on_child_exit(worker.pid)
''
