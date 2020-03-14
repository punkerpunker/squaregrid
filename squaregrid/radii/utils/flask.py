import logging
import threading
from werkzeug.serving import make_server


class FlaskServingThread(threading.Thread):
	def __init__(self, app, host, port):
		threading.Thread.__init__(self, name='FlaskServerThread')
		self.server_ = make_server(host, port, app)
		self.context_ = app.app_context()
		self.context_.push()
		logging.info('Initializing Flask server at http://%s:%d' % (host, port))

	def run(self):
		logging.info('Starting Flask server')
		self.server_.serve_forever()

	def shutdown(self):
		self.server_.shutdown()
