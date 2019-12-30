import sys

from werkzeug.contrib.fixers import ProxyFix

sys.path.insert(0, "/srv/nemesis/nemesis")

from app import app

app.config['PREFERRED_URL_SCHEME'] = 'https'

app = ProxyFix(app)

# SCRIPT_NAME fix, needed under Gunicorn. Adapted from
# https://github.com/antarctica/flask-reverse-proxy-fix and
# https://stackoverflow.com/questions/33051034/django-not-taking-script-name-header-from-nginx
# Likely we can drop this when we get to werkzeug>=0.15 when ProxyFix has more
# options and may be able to do this for us too.
def application(environ, start_response):
    SCRIPT_NAME = '/userman'
    environ['SCRIPT_NAME'] = SCRIPT_NAME
    path_info = environ['PATH_INFO']
    if path_info.startswith(SCRIPT_NAME):
        environ['PATH_INFO'] = path_info[len(SCRIPT_NAME):]

    return app(environ, start_response)
