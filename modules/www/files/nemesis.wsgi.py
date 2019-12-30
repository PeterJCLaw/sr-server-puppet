import sys

from werkzeug.contrib.fixers import ProxyFix

sys.path.insert(0, "/srv/nemesis/nemesis")

from app import app

app.config['PREFERRED_URL_SCHEME'] = 'https'

application = ProxyFix(app)
