import sys

from werkzeug.middleware.proxy_fix import ProxyFix

sys.path.insert(0, "/srv/nemesis/nemesis")

from app import app

app.config['PREFERRED_URL_SCHEME'] = 'https'

# Rely on nginx passing through various data for us to use. Note that the prefix
# needs to be explicit so it is correctly included in urls in emails.
application = ProxyFix(app, x_prefix=1)
