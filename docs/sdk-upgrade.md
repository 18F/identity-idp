# Upgrade and A/B test Acuant SDK

Instructions to upgrade the Acuant JavaScript Web SDK, which the identity-idp app uses for identity document image capture.
* [§ Watch SDK versions](#watch-sdk-versions)
* [§ Add new SDK files](#add-new-sdk-files)
* [§ Turn on A/B testing](#turn-on-ab-testing)
* [§ Monitor A/B testing](#monitor-ab-testing)
* [§ Switch over to new version](#switch-over-to-new-version)

## Watch SDK versions

New versions come from [this Acuant repo](https://github.com/Acuant/JavascriptWebSDKV11). We need to watch it so we know when to upgrade. 

Team members can sign up for notifications of new versions. In the repo, go to **Watch → Custom → Releases**.

## Add new SDK files

These steps add new, tested SDK files to the repo. They do not activate a new version of the SDK; they simply put it in place.

You will need:
* a mobile phone with a camera
* a USB cable that plugs into the phone
* your state ID, or a substitute wallet-sized card

Steps:

1. From [the list of Acuant SDK releases](https://github.com/Acuant/JavascriptWebSDKV11/releases), download the most recent release. Note the version number. The download will be a `.zip` or `.tar.gz` file. Uncompress it locally.

2. In your local checkout of the identity-idp repo, create a new version number directory under [`/public/acuant`](/public/acuant) named for the version you downloaded. The name will be similar to `/public/acuant/11.N.N`. You will be placing it alongside a few previous versions.

3. In your uncompressed download, open the `webSdk` folder. Copy all `.min.js` or `.wasm` files from here into the empty directory you created in the previous step. These files should have the same (or similar) names as files in the neighboring directories with previous version numbers.

4. This would be a good time to create a new Git branch, if you haven't done so already, and to commit the new version-numbered directory and its new SDK files.

5. Next, we must test the new SDK version. We will switch it on by setting our local default version of the Acuant SDK to our new version. Open the `/config/application.yml` file in your local repo. Set the `idv_acuant_sdk_version_default` key to the version number to be tested, creating that key if it does not yet exist. The result will look like:
    ```yml
    ---
    development:
      idv_acuant_sdk_version_default: '11.N.N'
    ```

6. Follow [these instructions to use the app from your mobile phone](mobile.md). Complete both the "Use the app from a mobile device" section, which lets you view the app from your phone, and the "Debugging with the desktop browser" portion, which hooks your desktop/laptop browser debugging tools to your phone via USB cable.

7. With your phone plugged into your computer via USB cable, and with your computer's browser debugging tools set to inspect a browser tab on your phone, navigate on your phone to the app's document capture page. This is the page that asks you to photograph your state ID card.

8. Inspect the `Sources` of the page. Under the local IP address from which you are serving the page, you should see a folder with a name like `acuant/11.9.0`. Check that the version number in this name is the version which you noted in step 1. This screenshot shows where the version number appears in Chrome:

    ![acuant-vesion-location](https://user-images.githubusercontent.com/546123/232644328-35922329-ad30-489e-943f-4125c009f74d.png)


9. Assuming the version is correct, you are ready to test it. On your phone, tap to photograph your state ID card. Point the camera at the card. Ensure the SDK finds the edges of the card and captures an image. Normally the SDK will put a yellowish box over the card to show were it believes the edges are.

10. After you have photographed the front and back of your card, you have tested the SDK locally. You do not need to submit the images. If you have both an Android and an iPhone, test the SDK with both of them. (Or, pair with someone who has the other type of phone.)

11. Open a pull request for the modified SDK files. The next process &mdash; A/B testing the new version &mdash; can only take place after the files are accepted into the main branch.

## Turn on A/B testing

After you have added the new SDK files per [the above instructions], and after those new files have been merged into the main Git branch, you may A/B test the new Acuant SDK version.

1. In identity-devops, run the command:

    ```zsh
    aws-vault exec prod-power -- bin/app-s3-secret --env prod --app idp --edit
    ```

    The command downloads a configuration file and opens an editor so you can modify it.

2. Make the file look like this:

    ```yml
    idv_acuant_sdk_upgrade_a_b_testing_enabled: true
    idv_acuant_sdk_upgrade_a_b_testing_percent: 50
    idv_acuant_sdk_version_alternate: 11.M.M
    idv_acuant_sdk_version_default: 11.N.N
    ```
 
    Set the default to the new SDK version and the alternate to the old version. (That way, the new version is in place for deafult use if the A/B testing goes well.)
    
3. Save the file. If the file opened in the vi editor, use `:wq` to save. A diff of your changes will appear. Type `y` to accept them.

4. Recycle the servers to cause the changes to take effect:

    ```zsh
    aws-vault exec prod-power -- bin/asg-recycle prod idp
    ```
    
    [This script](https://github.com/18F/identity-devops/wiki/Deploying-Infrastructure-Code#recycle-hosts) kicks off a migration instance instance, runs database migrations, and doubles the instances into a 50/50 state.

Monitoring the A/B test begins now.
