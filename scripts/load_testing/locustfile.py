import os
import pdb
from random import randint

from faker import Factory
import locust
import pyquery

import foney

import datetime

fake = Factory.create()
phone_numbers = foney.phone_numbers()

username, password = os.getenv('AUTH_USER'), os.getenv('AUTH_PASS')
auth = (username, password) if username and password else ()

# This should match however many users were created
# for the DB by the rake task.
NUM_USERS = 1000


def random_cred():
    """
    Given the rake task:
    rake dev:random_users NUM_USERS=100 SCRYPT_COST='800$8$1$'

    We should have 100 existing users with credentials matching:
    * email address testuser1@example.com through testuser1000@example.com
    * the password "salty pickles"
    * a phone number between +1 (415) 555-0001 and +1 (415) 555-1000.

    This will generate a set of credentials to match one of those entries.
    Note that YOU MUST run the rake task to put these users in the DB first.

    """
    return {
        'email': 'testuser{}@example.com'.format(randint(1, NUM_USERS-1)),
        'password': "salty pickles"
    }


def authenticity_token(dom, id=None):
    """
    Retrieves the CSRF auth token from the DOM for submission.
    If you need to differentiate between multiple CSRF tokens on one page,
    pass the optional ID of the parent form (with hash)
    """
    selector = 'input[name="authenticity_token"]:first'

    if id:
        selector = '{} {}'.format(id, selector)
    return dom.find(selector).attr('value')


def resp_to_dom(resp):
    """
    Little helper to check response status is 200
    and return the DOM, cause we do that a lot.
    """
    resp.raise_for_status()
    return pyquery.PyQuery(resp.content)


def login(t, credentials):
    """
    Takes a locustTask object and signs you in.
    """
    with t.client.get('/', catch_response=True) as resp:
        # If you're already logged in, it'll redirect to /account.
        # We need to handle this or you'll get all sorts of
        # downstream failures.
        if '/account' in resp.url:
            print("You're already logged in. We're going to quit login().")
            return resp

        dom = resp_to_dom(resp)
        token = authenticity_token(dom)

        if not token:
            resp.failure(
                "Not a sign-in page. Current URL is {}.".format(resp.url)
            )

    resp = t.client.post(
        resp.url,
        data={
            'user[email]': credentials['email'],
            'user[password]': credentials['password'],
            'authenticity_token': authenticity_token(dom),
            'commit': 'Submit',
        }
    )
    dom = resp_to_dom(resp)
    code = dom.find("#code").attr('value')

    if not code:
        # if we didn't see the code, then it's probably a failed login
        # due to un-reset credentials.
        # So let's try to rescue with the alternate pass.
        repost_resp = t.client.post(
            resp.url,
            data={
                'user[email]': credentials['email'],
                'user[password]': 'thisisanewpass',
                'authenticity_token': authenticity_token(dom),
                'commit': 'Submit',
            },
            catch_response=True
        )
        with repost_resp as resp:
            dom = resp_to_dom(resp)
            code = dom.find("#code").attr('value')

            # If we still don't have code, we have a bigger problem.
            if not code:
                resp.failure(
                    """
                    No 2FA code found after two tries.
                    Make sure {} is in the DB.
                    """.format(credentials)
                )
                return

    code_form = dom.find("form[action='/login/two_factor/sms']")
    resp = t.client.post(
        code_form.attr('action'),
        data={
            'code': code,
            'authenticity_token': authenticity_token(dom),
            'commit': 'Submit'
        }
    )
    # We're not checking for post-login state here,
    # as it will vary depending on the SP.
    resp.raise_for_status()
    return resp


def logout(t, page="/"):
    """
    Takes a locustTask object and signs you out.
    Naively assumes the user is actually logged in already.
    """
    with t.client.get(page, catch_response=True) as resp:
        dom = resp_to_dom(resp)
        sign_out_link = dom.find('a[href="/api/saml/logout"]').attr('href')
        if not sign_out_link:
            resp.failure("No signout link at {}.".format(resp.url))
            return
    # Authentication is now complete.
    # We've confirmed by the presence of the sign-out link.
    # We can now have the person sign out.
    resp = t.client.get(sign_out_link)
    resp.raise_for_status()


def change_pass(t, password):
    """
    Takes a locustTask and naively expects an already logged in person,
    this navigates to the account (which they should already be on, post-login)
    """
    resp = t.client.get('/account')
    dom = resp_to_dom(resp)
    edit_link = dom.find('a[href="/manage/password"]')

    try:
        resp = t.client.get(edit_link[0].attrib['href'])
    except Exception as error:
        resp.failure(
            """
            There was a problem finding the edit pass link: {}
            You may be hitting an OTP cap with this user,
            or did not run the rake task to generate users.
            Since we can't change the password, we'll exit.
            Here is the content we're seeing at {}: {}
            """.format(error, resp.url, dom('.container').eq(0).text())
        )
        return

    dom = resp_to_dom(resp)
    # To keep it simple for now we're skipping reauthn
    if '/manage/password' in resp.url:
        resp = t.client.post(
            resp.url,
            data={
                'update_user_password_form[password]': password,
                'authenticity_token': authenticity_token(dom),
                '_method': 'patch',
                'commit': 'update'
            }
        )
        resp.raise_for_status()
    else:
        # To-do: handle reauthn case
        resp.failure("Wrong redirect. Currently at {}".format(resp.url))


def signup(t, signup_url=None):
    """
    Creates a new account, starting at the home page,
    then navigating to create account page and submit email

    We're checking for signup_url to pass name and group results
    """
    new_email = 'test+{}@test.com'.format(fake.md5())
    default_password = "salty pickles"

    if signup_url:
        t.client.get(
            signup_url,
            auth=auth,
            name="/sign_up/start?request_id"
        )
    else:
        t.client.get('/sign_up/start', auth=auth)
    resp = t.client.get('/sign_up/enter_email', auth=auth)
    dom = resp_to_dom(resp)

    email_resp = t.client.post(
        '/sign_up/enter_email',
        data={
            'user[email]': new_email,
            'authenticity_token': authenticity_token(dom),
            'commit': 'Submit',
        },
        auth=auth,
        catch_response=True
    )
    with email_resp as resp:
        dom = resp_to_dom(resp)

        try:
            link = dom.find("a[href*='confirmation_token']")[0].attrib['href']
        except IndexError:
            if '/account' in resp.url:
                resp.failure(
                    """
                    Account appears to already be signed up and logged in.
                    Current URL: {}.
                    """.format(resp.url)
                )
            else:
                resp.failure(
                    """
                    Failed to get confirmation token.
                    Consult https://github.com/18F/identity-idp#load-testing
                    and check your application config. Current URL:
                    """.format(resp.url)
                )
            return

    # Follow email confirmation link and submit password
    resp = t.client.get(
        link,
        auth=auth,
        name='/sign_up/email/confirm?confirmation_token='
    )
    dom = resp_to_dom(resp)
    token = dom.find('[name="confirmation_token"]:first').attr('value')

    # Got to password page and submit
    resp = t.client.post(
        '/sign_up/create_password',
        data={
            'password_form[password]': default_password,
            'authenticity_token': authenticity_token(dom),
            'confirmation_token': token,
            'commit': 'Submit',
        },
        auth=auth
    )

    # After password creation, resp.url should be  /phone_setup
    # Now we have to get this page, then extract the correct auth token
    # so we can then turn around and post the confirmation token back.
    resp = t.client.get(resp.url)
    dom = resp_to_dom(resp)
    auth_token = authenticity_token(dom, '#new_user_phone_form')

    # Now post with the correct tokens
    phone_post = t.client.post(
        resp.url,
        data={
            '_method': 'patch',
            'user_phone_form[international_code]': 'US',
            'user_phone_form[phone]': phone_numbers[randint(1, 1000)],
            'user_phone_form[otp_delivery_preference]': 'sms',
            'authenticity_token': auth_token,
            'commit': 'Send security code',
        },
        auth=auth,
        catch_response=True
    )

    with phone_post as resp:
        dom = resp_to_dom(resp)
        try:
            otp_code = dom.find('input[name="code"]')[0].attrib['value']
        except Exception as error:
            resp.failure(
                "There was a problem with the OTP code: {}.".format(error))
            return

    # visit security code page and submit pre-filled OTP
    resp = t.client.post(
        '/login/two_factor/sms',
        data={
            'code': otp_code,
            'authenticity_token': authenticity_token(dom),
            'commit': 'Submit',
        },
        auth=auth
    )
    dom = resp_to_dom(resp)
    key = dom.find('.my4.border-box.separator-text').text()

    # Clicking "Continue" on key page triggers a modal, to which we post:
    resp = t.client.post(
        '/sign_up/personal_key',
        data={
            'authenticity_token': authenticity_token(dom, '#confirm-key'),
            'personal_key': key,
            'commit': 'Continue'
        },
        auth=auth
    )
    # We should now be fully signed in and will return
    # credentials + final page in case we with to log in again.
    return {
        'email': new_email,
        'password': default_password,
        'final_resp': resp
    }


class UserBehavior(locust.TaskSet):

    def on_start(self):
        pass

    @locust.task(1)
    def idp_change_pass(self):
        """
        Login, change pass, change it back and logout from IDP.

        This is given a very low weight, since we do not expect
        it to be a common pattern in the real world.
        """
        credentials = random_cred()
        login(self, credentials)
        change_pass(self, "thisisanewpass")
        # now change it back.
        change_pass(self, credentials['password'])
        logout(self)

    @locust.task(50)
    def idp_login_logout(self):
        """
        Login and logout from IDP. Very simple, but very common.
        """
        credentials = random_cred()
        login(self, credentials)
        logout(self)

    @locust.task(10)
    def idp_create_account(self):
        """
        Create an account from within the IDP.

        This has a low weight because it's uncommon in the real world.
        """
        new_account = signup(self)
        logout(self, new_account['final_resp'].url)

    @locust.task(2)
    def sp_rails_change_pass(self):
        """
        Login, change pass, change it back and logout from
        sp-rails sample app.

        This is given a very low weight, since we do not expect
        it to be a common pattern in the real world.
        """
        resp = self.client.get('http://localhost:3003')
        dom = resp_to_dom(resp)

        """
        # TO-DO: submit the LOA1/LOA3 form
        # We can't do this from form action yet, because there's a mismatch
        # in handling the trailing slash on host in locust and elsewhere:
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
        # For now, we're taking advantage of login() going to host + /sign_in
        """
        credentials = random_cred()
        login(self, credentials)
        change_pass(self, "thisisanewpass")
        # now change it back.
        change_pass(self, credentials['password'])
        logout(self)

    #@locust.task(10)
    def usajobs_change_pass(self):
        """
        Login, change pass, change it back and logout from USAjobs.
        """
        root_url = 'https://www.test.usajobs.gov'
        with self.client.get(root_url, catch_response=True) as resp:
            dom = resp_to_dom(resp)
            signin_link = dom.find(
                'a.user-logged-out[href="/Applicant/ProfileDashboard/Home"]'
            ).eq(0)

            if not signin_link:
                resp.failure(
                    "We could not find a signin link at {}".format(resp.url))

        transition_resp = self.client.get(
            root_url + signin_link[0].attrib['href'],
            catch_response=True
        )
        with transition_resp as resp:
            if resp.status_code is not 200:
                resp.failure(
                    "Bad {} response at {} with headers {}. Response:".format(
                        resp.status_code, resp.url, resp.headers, resp.content
                    )
                )
            # we should have been redirected to
            # https://login.test.usajobs.gov/Access/Transition.
            # Let's do a quick check.
            if "login.test.usajobs.gov/Access/Transition" not in resp.url:
                resp.failure(
                    """"
                    We do not appear to have been redirected to
                    https://login.test.usajobs.gov/Access/Transition.
                    Our current URL is {}, with content {}.
                    """.format(resp.url, resp.content)
                )
                return
        # Now that we've confirmed we're at the right URL
        # we need to POST to it, per USAjobs.
        handshake_post = self.client.post(
            resp.url,
            data={},
            name="/Access/Transition",
            catch_response=True
        )
        with handshake_post as resp:
            # Check to make sure we redirected to our target host,
            # with a request_id in resp.url
            if resp.url is not os.getenv('TARGET_HOST'):
                resp.failure(
                    """"
                    We do not appear to have been redirected to the IDP host.
                    Instead, we are at {}.
                    """.format(resp.url)
                )
                return
        credentials = random_cred()
        login(self, credentials)
        change_pass(self, "thisisanewpass")
        change_pass(self, credentials['password'])
        logout(self)

    #@locust.task(70)
    def usajobs_login_logout(self):
        """
        Login andlogout from USAjobs.

        This is a very common task and is heavily weighted.
         """
        root_url = 'https://www.test.usajobs.gov'
        with self.client.get(root_url, catch_response=True) as resp:
            dom = resp_to_dom(resp)
            signin_link = dom.find(
                'a.user-logged-out[href="/Applicant/ProfileDashboard/Home"]'
            ).eq(0)

            if not signin_link:
                resp.failure(
                    "We could not find a signin link at {}".format(resp.url)
                )

        sign_in_resp = self.client.get(
            root_url + signin_link[0].attrib['href'],
            catch_response=True
        )
        with sign_in_resp as resp:
            if resp.status_code is not 200:
                resp.failure(
                    "Bad {} response at {} with headers {}. Response:".format(
                        resp.status_code, resp.url, resp.headers, resp.content
                    )
                )
            # we should have been redirected to
            # https://login.test.usajobs.gov/Access/Transition.
            # Let's do a quick check.
            if "login.test.usajobs.gov/Access/Transition" not in resp.url:
                resp.failure(
                    """"
                    We do not appear to have been redirected to
                    https://login.test.usajobs.gov/Access/Transition.
                    Our current URL is {}, with content {}.
                    """.format(resp.url, resp.content)
                )
                return
        # Now that we've confirmed we're at the right URL
        # we need to POST to it, per USAjobs.
        handshake_post = self.client.post(
            resp.url,
            data={},
            name="/Access/Transition",
            catch_response=True
        )
        with handshake_post as resp:
            # Check to make sure we redirected to our target host,
            # with a request_id in resp.url
            if resp.url is not os.getenv('TARGET_HOST'):
                resp.failure(
                    """"
                    We do not appear to have been redirected to the IDP host.
                    Instead, we are at {}.
                    """.format(resp.url)
                )
                return
        credentials = random_cred()
        login(self, credentials)
        logout(self)

    #@locust.task(25)
    def usajobs_create_account(self):
        """
        Create an account from within USAjobs test domain.

        This is given a relatively low weight.
        It's much more common than account creation from within IDP
        but much lower than a simple login/logout.

        If the os env var "NO_LOGOUT" has been set, this will skip
        the logout step to help show the load of many open sessions.

        We have disabled method linting because:
        1. It counts arguments as separate lines
        2. This is how many steps it takes for the flow.
        """
        resp = self.client.get('https://www.test.usajobs.gov/')
        resp.raise_for_status()
        dash_response = self.client.get(
            'https://www.test.usajobs.gov/Applicant/ProfileDashboard/Home',
            catch_response=True
        )
        with dash_response as resp:
            if resp.status_code is not 200:
                resp.failure(
                    "Bad {} response at {} with the headers {}: {}".format(
                        resp.status_code, resp.url, resp.headers, resp.content
                    )
                )
                resp.raise_for_status()
        # A quick post is required to setup for the SP handshake.
        # We'll pass the response url to signup()
        # Note that you *must* cast to the "with" syntax or
        # catch_response will do bad, bad things.
        handshake_post = self.client.post(
            resp.url,
            data={},
            name="/Access/Transition (create)",
            catch_response=True
        )
        with handshake_post as resp:
            if resp.status_code is not 200:
                resp.failure(
                    "Bad {} response at {} with the headers {}".format(
                        resp.status_code, resp.url, resp.headers
                    )
                )
                resp.raise_for_status()
            signup(self, resp.url)

        # Unless we said not to, sign out now.
        if "NO_LOGOUT" in os.environ:
            print("Found 'NO_LOGOUT' in env vars. Skipping logout.")
        else:
            logout(self)


class WebsiteUser(locust.HttpLocust):
    task_set = UserBehavior
    min_wait = 50
    max_wait = 100
    host = os.getenv('TARGET_HOST') or 'http://localhost:3000'


if __name__ == '__main__':
    WebsiteUser().run()
