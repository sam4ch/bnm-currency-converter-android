# Иллюстрация фона

Файл: `assets/illustrations/floating_currency.png`.

Создан встроенным инструментом генерации изображений `image_gen` в Codex для обновления UI лабораторной. Использован режим новой генерации с `transparent_background: true`. Выбранный PNG скопирован в проект без обработки, с сохранением прозрачности. Это декоративная иллюстрация; она не изображает данные BNM.

Финальный промпт:

```text
Use case: stylized-concept. Asset type: transparent decorative foreground illustration for an Android currency converter, to be animated floating over a deep navy UI background. Create a premium sculptural 3D composition: a translucent mint/aqua glass sphere with a satin silver orbital ribbon, accompanied by two floating metal currency coins, one subtle embossed euro symbol and one dollar symbol. Minimal, elegant fintech visual, coherent single compact silhouette, three-quarter perspective, soft studio rim light and realistic glass refraction, mint highlights and deep blue reflections. Square canvas with generous transparent padding around the entire silhouette; all elements fully visible, no cropping. The artwork will appear small in the top right of a mobile app, so favor clear forms and restrained detail. No words, no numbers, no labels, no logos, no interface, no mockup, no background plane, no shadow rectangle. True transparent background.
```

Движение задаётся кодом Flutter: плавное смещение и небольшой поворот за 12 секунд, без повторной генерации картинки. Фон не принимает нажатия и исключён из дерева доступности. Системный параметр Android «Отключить анимацию» останавливает декоративное движение.
