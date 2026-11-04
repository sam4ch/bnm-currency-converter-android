# Background illustration

File: `assets/illustrations/floating_currency.png`.

Created with Codex's built-in `image_gen` image-generation tool for this lab's
UI update. A new image was generated with `transparent_background: true`.
The selected PNG was copied into the project without further processing,
preserving its transparency. This is a decorative illustration; it does not
represent BNM data.

Final prompt:

```text
Use case: stylized-concept. Asset type: transparent decorative foreground illustration for an Android currency converter, to be animated floating over a deep navy UI background. Create a premium sculptural 3D composition: a translucent mint/aqua glass sphere with a satin silver orbital ribbon, accompanied by two floating metal currency coins, one subtle embossed euro symbol and one dollar symbol. Minimal, elegant fintech visual, coherent single compact silhouette, three-quarter perspective, soft studio rim light and realistic glass refraction, mint highlights and deep blue reflections. Square canvas with generous transparent padding around the entire silhouette; all elements fully visible, no cropping. The artwork will appear small in the top right of a mobile app, so favor clear forms and restrained detail. No words, no numbers, no labels, no logos, no interface, no mockup, no background plane, no shadow rectangle. True transparent background.
```

Flutter code controls the motion: a smooth translation and slight rotation
over a 12-second cycle, without regenerating the image. The background does
not receive taps and is excluded from the accessibility tree. Android's
system setting to disable animations stops the decorative movement.
