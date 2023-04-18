# Upgrade and A/B test Acuant SDK

Instructions to upgrade the Acuant JavaScript Web SDK, which the identity-idp app uses for identity document image capture.
* [§ Watch SDK versions](#watch-sdk-versions)
* [§ Add new SDK files](#add-new-sdk-files)
* [§ Turn on A/B testing](#turn-on-ab-testing)
* [§ Monitor A/B testing](#monitor-ab-testing)
* [§ Switch versions](#switch-versions)

## Watch SDK versions

New versions come from [this Acuant repo](https://github.com/Acuant/JavascriptWebSDKV11). To determine if we need an upgrade, compare the [latest release](https://github.com/Acuant/JavascriptWebSDKV11/releases) version number to the latest in our [`/public/acuant`](/public/acuant) directory.

Someone on the team should watch the current version so we know when to upgrade. Team members can sign up for notifications of new versions at **Watch → Custom → Releases** in the Acuant repo.

## Add new SDK files

Steps in this section add new, tested SDK files to the repo. They do not activate a new version of the SDK; they simply put it in place.

You will need:
* a mobile phone with a camera (Android or iPhone or both)
* a USB cable that plugs into the phone
* your state ID, or a substitute wallet-sized card

Steps:

1. From [the list of Acuant SDK releases](https://github.com/Acuant/JavascriptWebSDKV11/releases), download the most recent release. Note the version number. The download will be a `.zip` or `.tar.gz` file. Uncompress it locally.

2. In your local checkout of the identity-idp repo, create a new version number directory under [`/public/acuant`](/public/acuant) named for the version you downloaded. The name will be similar to `/public/acuant/11.N.N`. You will be placing it alongside a few previous versions.

3. In your uncompressed download, open the `webSdk` folder. Copy all `.min.js` or `.wasm` files from here into the empty directory you created in the previous step. These files should have the same (or similar) names as files in the neighboring directories with previous version numbers.

4. This would be a good time to create a new Git branch, if you haven't done so already, and to commit the new version-numbered directory and its new SDK files.

5. Next, we must test the new SDK version. We will switch it on by setting our local default version of the Acuant SDK to our new version. Open the `/config/application.yml` file in your local repo. Set the `idv_acuant_sdk_version_default` key to the new version number. Create the key if it does not yet exist. The result will look like:
    ```yml
    ---
    development:
      idv_acuant_sdk_version_default: '11.N.N'
    ```

6. Follow [these instructions to use the app from your mobile phone](mobile.md). Complete both the "Use the app from a mobile device" section, which lets you view the app from your phone, and the "Debugging with the desktop browser" section, which hooks your desktop/laptop browser debugging tools to your phone via USB cable.

7. With your phone plugged into your computer via USB cable, and with your computer's browser debugging tools set to inspect a browser tab on your phone, navigate on your phone to the app's document capture page. This is the page that asks you to photograph your state ID card.

8. Inspect the `Sources` of the page. Expand the local IP address from which you are serving the page. You should see a folder with a version number in the name, like `acuant/11.N.N`. Check that the version here is the new one &mdash; the version you noted in step 1. This screenshot shows where the version number appears in Chrome:

    ![acuant-vesion-location](https://user-images.githubusercontent.com/546123/232644328-35922329-ad30-489e-943f-4125c009f74d.png)


9. Assuming the version is correct, you are ready to test it. On your phone, tap to photograph your state ID card. Point the camera at the card. Ensure the SDK finds the edges of the card and captures an image. Normally the SDK will put a yellowish box over the card to show where it believes the edges are.

10. After you have photographed the front and back of your card, you have tested the SDK locally. You do not need to submit the images. If you have both an Android and an iPhone, test the SDK with both of them. (Or, pair with someone who has the other type of phone.)

11. Open a pull request for the modified SDK files. The next process &mdash; A/B testing the new version &mdash; can only take place after the files are accepted into the main branch.

## Turn on A/B testing

After you have added the new SDK files per [the above instructions](#add-new-sdk-files), and after those new files have been merged into the main Git branch and deployed, you may A/B test the new Acuant SDK version.

You may want to first A/B tests in staging. These instructions show how to A/B test in production.

You will need:
* the AWS prod-power role ([request access](https://github.com/18F/identity-devops/issues/new?assignees=&labels=administration&template=onboarding-devops-prod.md&title=Onboarding+to+Production+for+%5BTEAM_MEMBER%5D))
* a YubiKey ([setup](https://github.com/18F/identity-devops/wiki/Setting-Up-your-Login.gov-Infrastructure-Configuration#configuring-a-yubikey-as-a-virtual-mfa-device))
* a GFE computer

1. In identity-devops, run the command:

    ```zsh
    aws-vault exec prod-power -- bin/app-s3-secret --env prod --app idp --edit
    ```

    The command downloads a configuration file and opens an editor so you can modify it.

2. Start a Slack thread in `#login-appdev` notifying people that you are going to recycle prod. An example message:
    > ♻ prod IdP to update Acuant SDK

3. Make the file look like this:

    ```yml
    idv_acuant_sdk_upgrade_a_b_testing_enabled: true
    idv_acuant_sdk_upgrade_a_b_testing_percent: 50
    idv_acuant_sdk_version_alternate: 11.M.M
    idv_acuant_sdk_version_default: 11.N.N
    ```
 
    Set the default to the new SDK version and the alternate to the old version. (That way, the new version is in place if the A/B testing goes well.) The percentage should already be set to 50, so it does not need to be changed.
    
4. Save the file. If the file opened in the vi editor, use `:wq` to save. A diff of your changes will appear. Copy the diff and paste it into the Slack thread. Type `y` to accept the changes.

5. Recycle the servers to deploy the changes:

    ```zsh
    aws-vault exec prod-power -- bin/asg-recycle prod idp
    ```
    
    The above uses [this script](https://github.com/18F/identity-devops/wiki/Deploying-Infrastructure-Code#recycle-hosts) to kick off a migration instance, run database migrations, and double the instances into a 50/50 state.

Monitoring the A/B test begins now. Proceed to the next section.

## Monitor A/B testing

#### For 15 minutes after deploy:

Use our [`ls-servers` command](https://handbook.login.gov/articles/devops-scripts.html#ls-servers) to view a table of our servers:

```zsh
aws-vault exec prod-power — bin/ls-servers -e prod
```

Monitor that the servers come back up after recycling. Check that they enter the `running` state and accumulate uptime.

Check NewRelic for errors during this time, also.

#### For the next 1 hour

After 15 minutes, per our [production deploy instructions](https://handbook.login.gov/articles/appdev-deploy.html#production), you may remove the old servers. This take us back out from a 50/50 deployment state. These commands are for **production only**. 

```zsh
aws-vault exec prod-power -- ./bin/scale-remove-old-instances prod idp
aws-vault exec prod-power -- ./bin/scale-remove-old-instances prod worker
```

Manually check the document capture page in the environment you are deploying to. Ensure the SDK loads and can capture images.

Check NewRelic for errors at the end of one hour.

#### For 2 weeks after deploy:

Monitor with this [AWS CloudWatch Acuant upgrade dashboard](https://us-west-2.console.aws.amazon.com/cloudwatch/home?region=us-west-2#dashboards:name=js-acuant-upgrade).

![pie-charts-sdk](https://user-images.githubusercontent.com/546123/232889932-432e5cd5-c460-4a0a-8c6b-9f54324f327b.png)

In this screenshot from the dashboard, the pie chart on the right shows a newer version of the SDK approaching 50% of document capture requests as A/B testing kicks in. The chart on the left shows that the newer version of the SDK is responsible for a proportionately lesser share of document capture failures, indicating that the new version is likely an improvement on the old.

If the new version of the SDK is performing well for a couple weeks of A/B testing, it is time to cut over 100% of traffic to the new version per the next section.

## Switch versions

When the test is concluded, for better or for worse, you'll want to end A/B testing, leaving only one SDK version. The procedure is the same as the above procedure to [turn on A/B testing](#turn-on-ab-testing) with one exception:

#### ✅ If the test went well

The only line in the configuration file that needs to be changed is this:

```yml
idv_acuant_sdk_upgrade_a_b_testing_enabled: false
```

This switches A/B testing off. The new, desired SDK version should already be set in the `idv_acuant_sdk_version_default` field, so it should not need to be changed. Double-check that this number is correct.

#### ❌ If the test went poorly

If the new version under A/B testing is performing poorly, you may want to end the test, returning to the *old* SDK version. Hence, you should set the default back to the version you want. Edit these two lines of the configuration file:

```yml
idv_acuant_sdk_upgrade_a_b_testing_enabled: false
idv_acuant_sdk_version_default: 11.M.M
```

#### 🔄 In either case
Save the configuration file, recycle, and monitor the recycle just as you did when you turned A/B testing on.

Once again, the command to recycle is:

```zsh
aws-vault exec prod-power -- bin/asg-recycle prod idp
```
Use the same [tools for monitoring](#monitor-ab-testing).

### Cleanup

After successful A/B testing clears us to move to a new version of the Acuant SDK, we want to remove the oldest version from our repository. In the `/public/acuant/`(/public/acuant/) directory, there should be three versions. We only want to keep the newer two. Delete the directory containing the oldest of the three versions. Create a pull request for this.
