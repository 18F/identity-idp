import os
import random

from faker import Factory
import locust
import pyquery

import foney

fake = Factory.create()

username, password = os.getenv('AUTH_USER'), os.getenv('AUTH_PASS')
auth = (username, password) if username and password else ()

phone_numbers = foney.phone_numbers()

def authenticity_token(dom):
    return dom.find('input[name="authenticity_token"]')[0].attrib['value']

class UserBehavior(locust.TaskSet):
    @locust.task
    def signup(self):
        # visit home page
        self.client.get('/', auth=auth)

        # visit create account page and submit email
        resp = self.client.get('/sign_up/enter_email', auth=auth)
        resp.raise_for_status()
        dom = pyquery.PyQuery(resp.content)
        data = {
            'user[email]': 'test+' + fake.md5() + '@test.com',
            'authenticity_token': authenticity_token(dom),
            'commit': 'Submit',
        }
        resp = self.client.post('/sign_up/enter_email', data=data, auth=auth)
        resp.raise_for_status()

        # capture email confirmation link on resulting page
        dom = pyquery.PyQuery(resp.content)
        link = dom.find("a[href*='confirmation_token']")[0].attrib['href']

        # click email confirmation link and submit password
        resp = self.client.get(link, auth=auth)
        resp.raise_for_status()
        dom = pyquery.PyQuery(resp.content)
        confirmation_token = dom.find('input[name="confirmation_token"]')[0].attrib['value']
        data = {
            'password_form[password]': 'salty pickles',
            'authenticity_token': authenticity_token(dom),
            'confirmation_token': confirmation_token,
            'commit': 'Submit',
        }
        resp = self.client.post('/sign_up/create_password', data=data, auth=auth)
        resp.raise_for_status()

        # visit phone setup page and submit phone number
        dom = pyquery.PyQuery(resp.content)
        data = {
            '_method': 'patch',
            'user_phone_form[international_code]': 'US',
            'user_phone_form[phone]': phone_numbers[random.randint(1,1000)],
            'user_phone_form[otp_delivery_preference]': 'sms',
            'authenticity_token': authenticity_token(dom),
            'commit': 'Send security code',
        }
        resp = self.client.post('/phone_setup', data=data, auth=auth)
        resp.raise_for_status()

        # visit enter security code page and submit pre-filled OTP
        dom = pyquery.PyQuery(resp.content)
        otp_code = dom.find('input[name="code"]')[0].attrib['value']
        data = {
            'code': otp_code,
            'authenticity_token': authenticity_token(dom),
            'commit': 'Submit',
        }
        resp = self.client.post('/login/two_factor/sms', data=data, auth=auth)
        resp.raise_for_status()

        # click Continue on personal key page
        dom = pyquery.PyQuery(resp.content)
        data = {
            'authenticity_token': authenticity_token(dom),
            'commit': 'Continue',
        }
        self.client.post('/sign_up/personal_key', data=data, auth=auth)

        # go straight to profile page
        self.client.get('/profile', auth=auth)

        # sign out
        self.client.get('/api/saml/logout', auth=auth)

class WebsiteUser(locust.HttpLocust):
    task_set = UserBehavior
    min_wait = 5000
    max_wait = 10000
