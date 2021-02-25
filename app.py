from app import app
import os

debug = os.environ['ENVIRONMENT'] == 'development'

app.run(host=os.environ['HOST'], port=os.environ['PORT'], debug=debug)
