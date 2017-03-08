import os

from faker import Factory
import locust
import pyquery

fake = Factory.create()

username, password = os.getenv('AUTH_USER'), os.getenv('AUTH_PASS')
auth = (username, password) if username and password else ()

class UserBehavior(locust.TaskSet):
    @locust.task
    def signup(self):
        # visit home page
        self.client.get('/', auth=auth)

        # visit create account page and submit email
        resp = self.client.get('/sign_up/enter_email', auth=auth)
        resp.raise_for_status()
        dom = pyquery.PyQuery(resp.content)
        auth_token = dom.find('input[name="authenticity_token"]')[0].attrib['value']
        data = {
            'user[email]': 'test+' + fake.md5() + '@test.com',
            'authenticity_token': auth_token,
            'commit': 'Submit',
        }
        resp = self.client.post('/sign_up/register', data=data, auth=auth)
        resp.raise_for_status()

        # capture email confirmation link on resulting page
        dom = pyquery.PyQuery(resp.content)
        link = dom.find('a')[2].attrib['href']

        # click email confirmation link and submit password
        resp = self.client.get(link, auth=auth)
        resp.raise_for_status()
        dom = pyquery.PyQuery(resp.content)
        auth_token = dom.find('input[name="authenticity_token"]')[0].attrib['value']
        confirmation_token = dom.find('input[name="confirmation_token"]')[0].attrib['value']
        data = {
            'password_form[password]': 'salty pickles',
            'authenticity_token': auth_token,
            'confirmation_token': confirmation_token,
            'commit': 'Submit',
        }
        resp = self.client.post('/sign_up/create_password', data=data, auth=auth)
        resp.raise_for_status()

        # visit phone setup page and submit phone number
        dom = pyquery.PyQuery(resp.content)
        auth_token = dom.find('input[name="authenticity_token"]')[0].attrib['value']
        data = {
            'two_factor_setup_form[phone]': '7035550001',
            'two_factor_setup_form[otp_method]': 'sms',
            'authenticity_token': auth_token,
            'commit': 'Send passcode',
        }
        resp = self.client.patch('/phone_setup', data=data, auth=auth)
        resp.raise_for_status()

        # visit enter passcode page and submit pre-filled OTP
        dom = pyquery.PyQuery(resp.content)
        auth_token = dom.find('input[name="authenticity_token"]')[0].attrib['value']
        otp_code = dom.find('input[name="code"]')[0].attrib['value']
        data = {
            'code': otp_code,
            'authenticity_token': auth_token,
            'commit': 'Submit',
        }
        resp = self.client.post('/login/two_factor/sms', data=data, auth=auth)
        resp.raise_for_status()

        # click Continue on recovery code page
        dom = pyquery.PyQuery(resp.content)
        auth_token = dom.find('input[name="authenticity_token"]')[0].attrib['value']
        data = {
            'authenticity_token': auth_token,
            'commit': 'Continue',
        }
        self.client.post('/sign_up/recovery_code', data=data, auth=auth)

        # go straight to profile page
        self.client.get('/profile', auth=auth)

        # sign out
        self.client.get('/api/saml/logout', auth=auth)

class WebsiteUser(locust.HttpLocust):
    task_set = UserBehavior
    min_wait = 5000
    max_wait = 10000
