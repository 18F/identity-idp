import os
import pdb

import locust
import pyquery


def authenticity_token(dom):
    """
    Retreives the CSRF auth token from the dom for submission
    """
    return dom.find('input[name="authenticity_token"]').eq(0).attr('value')


def login(t):
    """
    Takes a locustTask object and signs you in.

    To-do: 
    1. pull credentials from sqllite db
    2. figure out how to handle invalid login attempts.
    3. Handle account locks
    """
    print('beginning login')
    

    # begin at splash page
    t.client.get('/sign_up/start')

    # then go to sign-in page and submit credentials
    resp = t.client.get('/')
    resp.raise_for_status()
    dom = pyquery.PyQuery(resp.content)

    resp = t.client.post(
        '/',
        data = {
            'user[email]': t.temp_email,
            'user[password]': t.temp_pass,
            'authenticity_token': authenticity_token(dom),
            'commit': 'Submit',
        }
    )
    resp.raise_for_status()

    dom = pyquery.PyQuery(resp.content)
    try:
        code = dom.find("#code")
        # It's prompting for a 2FA code, so we know it was a valid login
        resp = t.client.post(
            '/login/two_factor/sms',
            data = {
                'code': code.attr('value'),
                'authenticity_token': authenticity_token(dom),
                'commit': 'Submit'
            }
        )
        resp.raise_for_status()
        print('Sign in complete.')
        #pdb.set_trace()
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


def change_pass(t):
    """
    Takes a locustTask and naively expects an already logged in person,
    this navigates to the account (which they should already be on, post-login)
    """
    
    resp = t.client.get('/account')
    resp.raise_for_status()
    dom = pyquery.PyQuery(resp.content)
    edit_link = dom.find('a[href="/manage/password"]')

    try:
        resp = t.client.get(edit_link.eq(0).attr('href'))
    except Exception as error:
        print("""
            There was a problem finding the edit pass link.
            Most likely, you're hitting an OTP cap with this user.
            We are unable to change the password and are exiting.
            """
        )
        print(error)
        return

    resp.raise_for_status()
    dom = pyquery.PyQuery(resp.content)
    # do we want to check that you're on the page where you insert your old pass?
    # we could look for form action before proceeding to the post?
    # Note that if you follow the form action it may take you
    # to /reauthn and we would need to handle that case. 
    # To keep it simple for now we're skipping reauth

    if resp.url == '/manage/password':
        resp = t.client.post(
            '/manage/password',
            data = {
                'update_user_password_form[password]': "Thisisanewpass",
                'authenticity_token': authenticity_token(dom),
                'commit': 'Submit',
            }
        )
        resp.raise_for_status()
        dom = pyquery.PyQuery(resp.content)
        print(dom.find('div.alert-notice').eq(0).text())
        # Now change it back
        resp = t.client.post(
            '/manage/password',
            data = {
                'update_user_password_form[password]': t.temp_pass,
                'authenticity_token': authenticity_token(dom),
                'commit': 'Submit',
            }
        )
        resp.raise_for_status()
        dom = pyquery.PyQuery(resp.content)
        print(dom.find('div.alert-notice').eq(0).text())
        pdb.set_trace()
    else:
        # To-do: handle reauthn case
        print(resp.url)
    

    


class UserBehavior(locust.TaskSet): 
    """
    1. Log in
    2. Change password
    3. Change it back.
    4. Log out.

    """
    temp_email = 'test1@test.com'
    temp_pass = 'thisisapass'

    def on_start(self):
        pass

    @locust.task
    def idp_change_pass(self): 
        login(self)
        change_pass(self)
        logout(self)
        # TO-DO: Put logout in on_stop once it's merged into locust
        # https://github.com/locustio/locust/pull/658


class WebsiteUser(locust.HttpLocust):
    task_set = UserBehavior
    min_wait = 50
    max_wait = 100
    host = os.getenv('TARGET_HOST') or 'http://localhost:3000'


if __name__ == '__main__':
    WebsiteUser().run()
