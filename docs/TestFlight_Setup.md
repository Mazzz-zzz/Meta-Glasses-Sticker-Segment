# TestFlight Setup for Auto Stickers

To configure TestFlight for Auto Stickers, navigate to App Store Connect, then go to Apps, select Auto Stickers, click on Distribution, and open the TestFlight section.

---

## Beta App Information

The locale should be set to English (U.S.).

### Beta App Description

Auto Stickers turns your Meta Ray-Ban smart glasses into a sticker-making machine. Stream live video from your glasses, and our AI automatically detects and cuts out objects to create perfect stickers. Choose from multiple styles including outlined, cartoon, glossy, and vintage effects.

This beta includes live video streaming from Meta Ray-Ban glasses, AI-powered object segmentation using SAM3, and automatic sticker generation from detected objects. You can apply multiple sticker styles including Default, Outlined, Cartoon, Minimal, Glossy, and Vintage. The app features a sticker library with favorites and organization, customizable detection prompts for objects like person, car, hand, and face, and adjustable stream quality and frame rate settings.

In this beta we are testing glasses connection stability, segmentation accuracy, sticker quality across different styles, and app performance during extended streaming sessions. We would love your feedback on the sticker quality and any objects that do not segment well.

### Contact Information

The feedback email should be set to almaz@cybergarden.app. The marketing URL should point to https://cybergarden.app/autostickers and the privacy policy URL should be https://cybergarden.app/privacy.

---

## Beta App Review Information

### Contact Information

The first name is Almaz and the last name is Khalilov. You will need to add your phone number. The email address is almaz@cybergarden.app.

### Sign-In Information

Sign-in is not required for this app. The app connects directly to the Meta AI app for glasses pairing, so no account or sign-in is needed within Auto Stickers itself.

### Review Notes

Auto Stickers requires Meta Ray-Ban smart glasses to function. The app uses the Meta Wearables SDK to connect to the glasses.

To test the app, first pair your Meta Ray-Ban glasses with your iPhone using the Meta AI app. Then open Auto Stickers and tap the Connect my glasses button. You will need to approve the connection in the Meta AI app. Once connected, start streaming to see live video from your glasses. Objects will be automatically detected and converted to stickers.

If you do not have Meta glasses available, the app will show the home screen with connection instructions. The Library and Settings tabs are still accessible so you can review the UI without glasses connected.

The app uses the fal.ai SAM3 API for image segmentation. An API key is embedded in the app for beta testing purposes.

---

## Testers Configuration

For internal testing, there is a group called "me" which is used for developer testing.

For external testing, there is a group called "friends" which includes trusted beta testers who have Meta glasses.

---

## Checklist Before Submitting

The beta app description has been filled out. The feedback email has been configured. The privacy policy URL and marketing URL have been set. The contact information is complete. Sign-in is not required since the app uses the Meta AI app for authentication. The review notes explain the glasses requirement.

You still need to upload screenshots to App Information and set the app category to Photo and Video.

---

## App Screenshots Needed

For TestFlight and the App Store, you will need the following screenshots. The first screenshot should show the home screen with the Connect my glasses button. The second screenshot should show the live streaming view with the video feed. The third screenshot should show the Cutout tab with the prompt chips. The fourth screenshot should show the Style selection grid. The fifth screenshot should show the Sticker library with saved stickers. The sixth screenshot should show the Settings panel.

---

## Device Requirements

The app requires an iPhone running iOS 17.0 or later. For full functionality, you need Meta Ray-Ban smart glasses. The Meta AI app must be installed and your glasses must be paired before using Auto Stickers.

---

## Quick Links

You can access App Store Connect at https://appstoreconnect.apple.com. Documentation for the Meta Wearables SDK is available at https://developers.facebook.com/docs/meta-wearables/. Information about the fal.ai SAM3 API can be found at https://fal.ai/models/fal-ai/sam3.
