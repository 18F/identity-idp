import os
import pdb
from random import randint

from faker import Factory
import locust
import pyquery

import foney

fake = Factory.create()
phone_numbers = foney.phone_numbers()

username, password = os.getenv('AUTH_USER'), os.getenv('AUTH_PASS')
auth = (username, password) if username and password else ()

# This should match however many users were created
# for the DB by the rake task.
NUM_USERS = 100

def random_cred():
    """
    Given the rake task:
    rake dev:random_users NUM_USERS=1000 SCRYPT_COST='800$8$1$'

    We should have 1000 existing users with credentials matching:
    * email address testuser1@example.com through testuser1000@example.com
    * the password "salty pickles"
    * a phone number between +1 (415) 555-0001 and +1 (415) 555-1000.

    This will generate a set of credentials to match one of those entries.
    Note that YOU MUST run the rake task to put these users in the DB first.

    """
    return {
        'email': 'testuser{}@example.com'.format(randint(1, NUM_USERS)),
        'password': "salty pickles"
    }

def authenticity_token(dom):
    """
    Retrieves the CSRF auth token from the DOM for submission
    """
    return dom.find('input[name="authenticity_token"]').eq(0).attr('value')

def login(t, credentials):
    """
    Takes a locustTask object and signs you in.

    To-do:
    1. pull credentials from sqllite db
    2. figure out how to handle invalid login attempts.
    3. Handle account locks
    """
    print('beginning sign in with credentials: {}'.format(credentials))
    t.client.get('/sign_up/start')

    # then go from splash page to sign-in page and submit credentials
    resp = t.client.get('/')
    resp.raise_for_status()
    dom = pyquery.PyQuery(resp.content)

    resp = t.client.post(
        '/',
        data = {
            'user[email]': credentials['email'],
            'user[password]': credentials['password'],
            'authenticity_token': authenticity_token(dom),
            'commit': 'Submit',
        }
    )
    resp.raise_for_status()
    dom = pyquery.PyQuery(resp.content)
    try:
        code = dom.find("#code")
        # It's prompting for a 2FA code, so we know it's a valid login
        resp = t.client.post(
            '/login/two_factor/sms',
            data = {
                'code': code.attr('value'),
                'authenticity_token': authenticity_token(dom),
                'commit': 'Submit'
            }
        )
        resp.raise_for_status()
        print('Sign in complete. Currently at {}.'.format(resp.url))
    except Exception as error:
        print(error)

def logout(t):
    """
    Takes a locustTask object and signs you out.
    Naively assumes the user is actually logged in already.
    """
    print('Beginning sign out')
    resp = t.client.get('/')
    resp.raise_for_status()
    dom = pyquery.PyQuery(resp.content)

    try:
        sign_out_link = dom.find('a[href="/api/saml/logout"]')
        # Authentication is now complete.
        # We've confirmed by the presence of the sign-out link.
        # We can now have the person sign out.
        resp = t.client.get(sign_out_link.attr('href'))
        resp.raise_for_status()
        dom = pyquery.PyQuery(resp.content)
        # Let's confirm:
        print(dom.find('div.alert-success').eq(0).text())
    except Exception as error:
        print(error)

def change_pass(t, password):
    """
    Takes a locustTask and naively expects an already logged in person,
    this navigates to the account (which they should already be on, post-login)
    """

    resp = t.client.get('/account')
    resp.raise_for_status()
    dom = pyquery.PyQuery(resp.content)
    edit_link = dom.find('a[href="/manage/password"]')

    try:
        resp = t.client.get(edit_link[0].attrib['href'])
    except Exception as error:
        print("""
            There was a problem finding the edit pass link: {}
            Most likely, you're hitting an OTP cap with this user, 
            or did not run the rake task to generate users.
            Since we can't change the password, we'll exit.
            Here is the content we're seeing at {}: {}
            """.format(error, resp.url, dom('.container').eq(0).text())
        )
        return

    resp.raise_for_status()
    dom = pyquery.PyQuery(resp.content)
    # To keep it simple for now we're skipping reauth
    if '/manage/password' in resp.url:
        resp = t.client.post(
            resp.url,
            data = {
                'update_user_password_form[password]': password,
                'authenticity_token': authenticity_token(dom),
                '_method': 'patch',
                'commit': 'update'
            }
        )
        resp.raise_for_status()
        dom = pyquery.PyQuery(resp.content)
        print(dom.find('div.alert-notice').eq(0).text())
    else:
        # To-do: handle reauthn case
        print(resp.url)

def signup(t, signup_url='/sign_up/start'):
    """
    Creates a new account.
    """
    # start at home page,
    # then navigate to create account page and submit email
    t.client.get(signup_url, auth=auth)
    resp = t.client.get('/sign_up/enter_email', auth=auth)
    resp.raise_for_status()

    data = {
        'user[email]': 'test+' + fake.md5() + '@test.com',
        'authenticity_token': authenticity_token(pyquery.PyQuery(resp.content)),
        'commit': 'Submit',
    }
    resp = t.client.post(
        '/sign_up/enter_email',
        data=data,
        auth=auth
    )
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
    resp = t.client.get(
        link,
        auth=auth,
        name='/sign_up/email/confirm?confirmation_token='
    )
    resp.raise_for_status()

    dom = pyquery.PyQuery(resp.content)
    confirmation_token = dom.find('[name="confirmation_token"]')[0].attrib['value']
    data = {
        'password_form[password]': 'salty pickles',
        'authenticity_token': authenticity_token(dom),
        'confirmation_token': confirmation_token,
        'commit': 'Submit',
    }
    resp = t.client.post(
        '/sign_up/create_password', data=data, auth=auth)
    resp.raise_for_status()

    # visit phone setup page and submit phone number
    dom = pyquery.PyQuery(resp.content)
    data = {
        '_method': 'patch',
        'user_phone_form[international_code]': 'US',
        'user_phone_form[phone]': phone_numbers[randint(1,1000)],
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


class UserBehavior(locust.TaskSet):
    """
    # TO-DO: Put logout in on_stop once it's merged into locust
        # https://github.com/locustio/locust/pull/658

    """
    def on_start(self):
        pass

    #@locust.task(1)
    def idp_change_pass(self):
        """
        Login, change pass, change it back and logout from IDP.

        This is given a very low weight, since we do not expect
        it to be a common pattern in the real world.
        """
        print("Task: Change pass from IDP")
        credentials = random_cred()
        login(self, credentials)
        change_pass(self, "thisisanewpass")
        # now change it back.
        change_pass(self, credentials['password'])
        logout(self)

    #@locust.task(2)
    def sp_rails_change_pass(self):
        """
        Login, change pass, change it back and logout from
        sp-rails sample app.

        This is given a very low weight, since we do not expect
        it to be a common pattern in the real world.
        """
        print("Task: Change pass from sp_rails")
        resp = self.client.get('http://localhost:3003')
        resp.raise_for_status()
        dom = pyquery.PyQuery(resp.content)

        # now submit the LOA1/LOA3 form
        """
        # We can't do this programmatically yet, because there's a mismatch
        # in how we're handling the trailing slash on host in locust and elsewhere:
        # in requests/models.py", line 371, in prepare_url
        #     scheme, auth, host, port, path, query, fragment = parse_url(url)
        # results in localhost:3000auth rather than localhost:3000/auth/saml/
        # Until we get that sorted out, this will need to be commented out
        # and we'll manually go to the IPD url.

        resp = self.client.post(
            dom.find("form").eq(0).attr('action'),
            data = {
                'loa': 1,
                'authenticity_token': authenticity_token(dom)
            }
        )
        For now, we're taking advantage of login() going to host + /sign_in
        """
        credentials = random_cred()
        login(self, credentials)
        change_pass(self, "thisisanewpass")
        # now change it back.
        change_pass(self, credentials['password'])
        logout(self)

    #@locust.task(70)
    def usajobs_change_pass(self):
        """
        Login, change pass, change it back and logout from USAjobs.
        """
        print("Task: Change pass from usajobs")
        resp = self.client.get('https://www.test.usajobs.gov/')
        resp.raise_for_status()
        resp = self.client.get('https://www.test.usajobs.gov/Applicant/ProfileDashboard/Home')
        resp.raise_for_status()
        # we should now have been redirected to
        # https://login.test.usajobs.gov/Access/Transition
        # we could put a resp.url check in here to verify that
        # We'll now navigate into the regular IDP login flow.
        credentials = random_cred()
        login(self, credentials)
        change_pass(self, "thisisanewpass")
        # now change it back.
        change_pass(self, credentials['password'])
        logout(self)

    #@locust.task(2)
    def idp_create_account(self):
        print("Task: Create account from idp")
        signup(self)
        logout(self)

    @locust.task(25)
    def usajobs_create_account(self):
        print("Task: Create account from usajobs")
        resp = self.client.get('https://www.test.usajobs.gov/')
        resp.raise_for_status()
        resp = self.client.get('https://www.test.usajobs.gov/Applicant/ProfileDashboard/Home')
        resp.raise_for_status()
        # A quick post to setup for the SP handshake
        resp = self.client.post('https://login.test.usajobs.gov/Access/Transition')
        resp.raise_for_status()
        signup_url = resp.url
        signup(self, signup_url)
        logout(self)


class WebsiteUser(locust.HttpLocust):
    task_set = UserBehavior
    min_wait = 50
    max_wait = 100
    host = os.getenv('TARGET_HOST') or 'http://localhost:3000'


if __name__ == '__main__':
    WebsiteUser().run()
