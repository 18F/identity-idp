# Mobile local development

Instructions to use an iPhone or Android mobile device for local app development, in two sections:

- [§ Use the app from a mobile device](#use-the-app-from-a-mobile-device) by running it over your home or office WiFi
- [§ Debugging with the desktop browser](#debugging-with-the-desktop-browser) by plugging your phone into your computer with a USB cable

## Use the app from a mobile device

These instructions will configure your local copy of the identity-idp app to serve web pages over your local computer network &mdash; the wifi in your home or office. You can broadcast the app to a mobile phone or tablet. Both your mobile device and your development computer (your laptop) must be connected to the same wifi network.

By default, the application binds to `localhost`. To access it from a mobile device on the same network, you will need to bind it to an accessible IP address.

1. Find your Local Area Network IP address. On a MacBook, this is available at **System Preferences → Network**. The IP address you are looking for likely starts with `192.168.` or `10.`

2. In your app's `application.yml` file, add the below. Be sure to indent these lines and include them in the `development:` section. Also, fill in your actual LAN IP address. The final line creates a **confirm now** link in place of email confirmation.

```yaml
development:
  domain_name: <YOUR IP ADDRESS>:3000
  mailer_domain_name: <YOUR IP ADDRESS>:3000
  enable_load_testing_mode: true
```

3. Start your app's local web server with:

```bash
HOST=<YOUR IP ADDRESS> make run-https
```

4. On your phone's browser, open a new tab. In the address bar, type in `https://` (don't forget the `s`) followed by your LAN IP and port number (like `https://192.168.x.x:3000`). When you visit this page, you may see a **Your connection is not private** message. Click **Advanced** and **Proceed** to continue. You should then see the sign in screen of the identity-idp app.

After you complete these steps, pages from the app are served from your development machine to your mobile device, where you may now use the identity-idp app. For front-end development, you may now want to turn on browser development tools per the next section of these instructions.

### Special instructions for iOS

It is becoming more common for browsers to entirely block access to sites using self-signed certificates, not even providing an escape hatch like the one described above.

If you are not able to access the locally running app from your iPhone, follow these steps:

#### 1. Somehow get the `.crt` file into the iOS Files app

When you run `make run-https`, the system generates a self-signed SSL certificate for you and stores it in the `tmp` directory. The file will be named something like `<YOUR IP ADDRESS>-3000.crt`. You need to get that file onto your phone and into the iOS Files app.

One way to do this is via Google Drive:

1. Upload the file to Google Drive.
2. Open the Google Drive app on your phone and "Download" the `.crt` file.
3. When prompted for a destination, select "Save to Files".

#### 2. Import the certificate into iOS

1. Open the Files app.
2. Tap on the `.crt` file (fun fact: it may now show a `.cer` extension!).
3. You should see some kind of message about a profile being downloaded.
4. Open the Settings app. Notice you have a new "Profile Downloaded" item there. Tap that.
5. Install the profile. You will be prompted for confirmation many times.

#### 3. Trust the certificate

1. Go to **Settings > General > About > Certificate Trust Settings**.
2. Tick the little box next to the certificate you just installed.

At this point, you _should_ be able to access the IdP running on your local development computer from your phone.

> [!WARNING]
> Do not forget to un-trust the certificate and remove the profile when you are done.

## Debugging with the desktop browser

After you have completed the [§ Use the app from a mobile device](#use-the-app-from-a-mobile-device) instructions above, you may further want to use your desktop browser's development and dubugging tools.

To do this, you will plug your phone into your laptop. You will need a USB cable. It does not work via WiFi.

### Android / Chrome

These instructions will allow you to debug your phone browser with Chrome DevTools on your development machine. Also, they let you view and interact with your phone's browser screen on your laptop screen or development monitor, which lets you screenshare your development work with coworkers.

1. In your Android phone, turn on USB debugging. This will allow your development computer to connect to your phone.

   **USB debugging** is a setting in the **Developer options** menu. This menu may be hidden on your phone. It can be revealed with a ["magic tap"](https://developer.android.com/studio/debug/dev-options) on the phone **Build number** 7 times.

2. Plug your Android phone into your development computer with a USB cable. (A USB hub may or may not work.) If you see a message on your phone asking you to **Allow USB debugging** click to allow it.

3. In the Chrome web browser of your development computer, visit `chrome://inspect`

4. Click on **Port forwarding**. Create/ensure the following entries:
   - Port 3000 forwarded to localhost:3000
   - Port 3035 forwarded to localhost:3035 (This is needed to ensure that JavaScript resources can be accessed through webpack)

Check **Enable port forwarding** and click **Done**. These screenshots illustrates enabling port forwarding on a MacBook:

|                                                    Click on Port forwarding                                                    |                                                       Enter IP and enable                                                        |
| :----------------------------------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------------------------------------: |
| ![port-forwarding-button](https://user-images.githubusercontent.com/546123/231608927-5f577e1a-bc82-47c6-b69a-d592c551a99f.png) | ![port-forwarding-settings](/docs/images/port-forwarding-settings.png) |

5. You should now be able to access the application by navigating to http://localhost:3000 on your device.

6. Back on your development computer, in the `chrome://inspect` tab, below the "Remote Target" heading, you should see a listing of all the tabs open on your phone. Find the item on the list that represents the sign in screen of the identity-idp app. It should be at the top of the list.

If you don't see any tabs under the "Remote Target" heading, you may need to try a different method of connecting your phone to your computer. In your terminal, you can run the command `ioreg -p IOUSB` to see what is connected to your USB ports. If your phone is connected to a USB hub but is not listed in the output, try connecting your phone directly to the computer. You could also try using a different USB cable.

7. Click to **inspect** this tab. You should see browser DevTools and a representation of your phone's screen on your development computer, as in this illustration:

<img width="800" alt="inspect-androd-chrome-tab" src="https://user-images.githubusercontent.com/546123/231608143-aff2e115-e672-4411-8670-79f86fcf58ad.png">

### iPhone / Safari or Chrome

These instructions work only if your development computer is an Apple product. You will need a USB cable with the appropriate "lightning" connector to plug into an iPhone.

1. On your development Apple machine, open the Safari web browser. Go to menu items **Safari → Settings → Advanced** and check **Show Develop menu in menu bar**. (For some OS versions, it may be **Safari → Preferences → Advanced**.) A screenshot:

   ![show_develop_menu](https://user-images.githubusercontent.com/546123/232129916-3c68d950-1145-4af6-9a1a-c8e7c3dea7a1.png)

2. Take a glance at the newly-revealed **Develop** menu item in Safari. Seeing how the menu looks now may help you find your iPhone when it later appears in the menu.

3. Turn on Web Inspector for your phone browser
    - Safari: On your iPhone, go to **Settings → Safari → Advanced** and turn on Web Inspector. Make sure JavaScript is also on.
    - Chrome: On your iPhone, go to **Chrome App → ... → Settings → Content Settings** and turn on Web Inspector.

4. Plug your iPhone into your development computer with a USB cable. (A USB hub may or may not work.) If you see a message on your phone asking you to **Trust This Computer?** click to trust it.

5. Revisit the Safari **Develop** menu of your laptop. You'll see a menu item that wasn't there before: the name of your phone.

6. In that menu item, click the "Connect via Network" option. This step is optional, but will enable you to debug over your wifi network without the USB cable. Once you've checked this option you can unplug the USB cable and continue with these steps. If you don't check this option, you can continue these steps with the USB cable connecting your iPhone and computer. A screenshot:

   ![develop-over-network](https://github.com/18F/identity-idp/assets/6818839/a672e33c-da63-4bd0-8e87-60bc6e89027c)

7. Within that menu item, you'll find a list of Safari browser tabs open on your iPhone. To see them, the iPhone must be unlocked, and the Safari browser must be displayed on the phone's screen.

8. Click on the tab you wish to inspect. You will see browser debugging tools like Elements, Console, and Layers. (Unlike the above Android instructions, you will not see a picture of your phone's browser screen on your laptop's screen.)
