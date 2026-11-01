# App icon artwork

Created with the built-in image generation tool. Master: `AppIcon-master.png`.
The gold Gothic doorway and crimson manuscript connect the
icon to the abbey and its central mystery. No game ROM artwork was used.

Regenerate the macOS ICNS representations from the checked-in master:

```sh
swift scripts/generate-icon.swift
make package
```

## Frameless edit prompt

Edit this macOS game icon. Remove ONLY the outer emerald rounded-square backing tile and its thin gold perimeter rim. Make all the area outside the Gothic architectural silhouette fully transparent, including the outer emerald side strips and bottom slab/backplate. Preserve the golden Gothic arch itself, its three columns on each side, the dark interior corridor with amber window light, and the red medieval book in front, with the same arrangement, shapes, scale, textures and colors. Keep the architectural arch intact: the user is removing the enclosing app-icon tile/frame, not the arch. The finished icon must be a free-standing cutout of the abbey doorway and crimson book, with real alpha transparency around its irregular silhouette. No new rounded square, no enclosing border, no extra frame, no text. Refine only the cut edges naturally. Do not add any objects.

## Original generation prompt

Use case: stylized-concept.
Asset type: production macOS application icon for the native game "La abadía del crimen", a medieval abbey murder mystery.
Create ONE superb icon, square 1024x1024. Transparent canvas outside the icon's rounded-square silhouette. A large, bold, sculpted Gothic archway in aged champagne gold / warm limestone, set into a deep emerald-green rounded-square tile. Within the arch, an atmospheric nearly black doorway with a narrow warm amber shaft of light. In the foreground at the base of the arch, a single unmistakable closed crimson medieval book, slightly angled, with a gold clasp and luminous ivory page edges. The book is the distinctive accent, not a tiny afterthought. Think premium handcrafted macOS game icon: dimensional materials, beautiful bevels, restrained cinematic lighting, clean silhouette, editorial elegance. Frontal view with gentle depth, icon fills about 90% of canvas, balanced centered composition. Architectural arch occupies the upper two thirds, book anchors lower third. Small icon legibility is critical: only these two large, simple forms, strong contrast, clear separation. Soft internal shadows and subtle edge highlights, emerald stone/enamel background, gold arch, rich crimson book. No writing, no letters, no logo, no border text, no skull, no people, no candles, no surrounding scenery. No mockup, no multiple icons, no contact sheet. Alpha transparent outside the rounded tile and its soft shadow.
