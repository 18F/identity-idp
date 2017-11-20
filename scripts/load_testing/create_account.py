import os
import pdb

from faker import Factory
import locust
import pyquery

fake = Factory.create()

username, password = os.getenv('AUTH_USER'), os.getenv('AUTH_PASS')
auth = (username, password) if username and password else ()

def authenticity_token(dom):
    return dom.find('input[name="authenticity_token"]')[0].attrib['value']


def signup(t):
    # visit home page
    t.client.get('/sign_up/start', auth=auth)

    # visit create account page and submit email
    resp = t.client.get('/sign_up/enter_email', auth=auth)
    resp.raise_for_status()
    dom = pyquery.PyQuery(resp.content)
    data = {
        'user[email]': 'test+' + fake.md5() + '@test.com',
        'authenticity_token': authenticity_token(dom),
        'commit': 'Submit',
    }
    resp = t.client.post('/sign_up/enter_email', data=data, auth=auth)
    resp.raise_for_status()

    dom = pyquery.PyQuery(resp.content)
    try:
        link = dom.find("a[href*='confirmation_token']")[0].attrib['href']
    except IndexError:
        print("""
            Failed to get confirmation token. 
            Consult https://github.com/18F/identity-idp#load-testing
            and check your application config."""
        )
        return

    # Follow email confirmation link and submit password
    resp = t.client.get(link, auth=auth)
    resp.raise_for_status()
    dom = pyquery.PyQuery(resp.content)
    confirmation_token = dom.find('input[name="confirmation_token"]')[0].attrib['value']

    data = {
        'password_form[password]': 'salty pickles',
        'authenticity_token': authenticity_token(dom),
        'confirmation_token': confirmation_token,
        'commit': 'Submit',
    }
    resp = t.client.post('/sign_up/create_password', data=data, auth=auth)
    resp.raise_for_status()

    # visit phone setup page and submit phone number
    dom = pyquery.PyQuery(resp.content)
    data = {
        '_method': 'patch',
        'user_phone_form[international_code]': 'US',
        'user_phone_form[phone]': '7035550001',
        'user_phone_form[otp_delivery_preference]': 'sms',
        'authenticity_token': authenticity_token(dom),
        'commit': 'Send security code',
    }
    resp = t.client.post('/phone_setup', data=data, auth=auth)
    resp.raise_for_status()

    # visit enter security code page and submit pre-filled OTP
    dom = pyquery.PyQuery(resp.content)
    try:
        otp_code = dom.find('input[name="code"]')[0].attrib['value']
    except Exception as error:
        print("There is a problem creating this account.")
        print(error)
        print(resp.content)
        return

    data = {
        'code': otp_code,
        'authenticity_token': authenticity_token(dom),
        'commit': 'Submit',
    }
    resp = t.client.post('/login/two_factor/sms', data=data, auth=auth)
    resp.raise_for_status()

    # click Continue on personal key page
    dom = pyquery.PyQuery(resp.content)
    data = {
        'authenticity_token': authenticity_token(dom),
        'commit': 'Continue',
    }
    t.client.post('/sign_up/personal_key', data=data, auth=auth)

    # go straight to profile page
    t.client.get('/profile', auth=auth)

    # sign out
    t.client.get('/api/saml/logout', auth=auth)


class UserBehavior(locust.TaskSet):
    
    @locust.task
    def idp_create_account(self): 
        print("Task: Create account from idp")
        signup(self)

    @locust.task
    def usajobs_create_account(self): 
        print("Task: Create account from usajobs")
        resp = self.client.get('https://www.test.usajobs.gov/')
        resp.raise_for_status()
        resp = self.client.get('https://www.test.usajobs.gov/Applicant/ProfileDashboard/Home')
        resp.raise_for_status()
        signup(self)


class WebsiteUser(locust.HttpLocust):
    task_set = UserBehavior
    min_wait = 5000
    max_wait = 10000
    host = os.getenv('TARGET_HOST') or 'http://localhost:3000'


if __name__ == '__main__':
    WebsiteUser().run()
