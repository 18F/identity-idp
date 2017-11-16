import os

import locust
import pyquery

def authenticity_token(dom):
    return dom.find('input[name="authenticity_token"]')[0].attrib['value']


class UserBehavior(locust.TaskSet):
    @locust.task
    def login(self):
        # to-do: pull these from sqllite db
        temp_email = 'test1@test.com'
        temp_pass = 'thisisapass'

        # begin at splash page
        self.client.get('/sign_up/start')

        # then go to sign-in page and submit credentials
        resp = self.client.get('/')
        resp.raise_for_status()
        dom = pyquery.PyQuery(resp.content)
        
        data = {
            'user[email]': temp_email,
            'user[password]': temp_pass,
            'authenticity_token': authenticity_token(dom),
            'commit': 'Submit',
        }
        resp = self.client.post('/', data=data)
        resp.raise_for_status()
        
        dom = pyquery.PyQuery(resp.content)
        code = dom.find("#code")
        if code:
            # It's prompting for a 2FA code, so we know it was a valid login
            resp = self.client.post(
                '/login/two_factor/sms',
                data = {
                    'code': code.attr('value'),
                    'authenticity_token': authenticity_token(dom),
                    'commit': 'Submit'
                }
            )
            resp.raise_for_status()
            print('Sign in complete. Signing out.')
            dom = pyquery.PyQuery(resp.content)
            sign_out_link = dom.find('a[href="/api/saml/logout"]')
            # Authentication is now complete.
            # We've confirmed by the presence of the sign-out link. 
            # We can now have the user sign out.
            if sign_out_link:
                resp = self.client.get(sign_out_link.attr('href'))
                resp.raise_for_status()
                dom = pyquery.PyQuery(resp.content)
                # Let's confirm:
                alert = dom.find('div.alert-success').eq(0)
                if alert.text() == 'You are now signed out.':
                    print('Sign out complete')

        # to do:
        #   - figure out how to handle invalid login attempts.
        #   - Handle account locks


class WebsiteUser(locust.HttpLocust):
    task_set = UserBehavior
    min_wait = 50
    max_wait = 100
    # for debugging ONLY!!!!!
    host = 'http://localhost:3000'


if __name__ == '__main__':
    WebsiteUser().run()
