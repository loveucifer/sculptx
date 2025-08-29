<p align="center">
  <img src="assets/images/logo.png" alt="SculptX Logo" width="150"/>
</p>



# SculptX

### Turn Visual Form into Audible Sound.

SculptX is an experimental synesthetic composer built with Flutter. It's a digital instrument that transforms 3D shapes into unique soundscapes in real-time. Every curve, angle, and manipulation of a shape creates a different tone, turning anyone into a visual composer.

---

## Features

-   **Preset & Procedural Shapes:** Start with a library of classic shapes (square, star) or explore complex, mathematically generated forms like a Torus Knot and Lissajous curve.
-   **Free-Form Drawing:** Activate Draw Mode to sculpt your own unique 3D glyphs from scratch.
-   **Real-Time 3D Manipulation:** Take control of your shape in 3D space.
    -   **Rotate & Scale:** Use intuitive pinch and drag gestures.
    -   **Extrude & Twist:** Use sliders to add depth and warp your creations.
-   **Advanced Audio Synthesis:** Fine-tune your sound with a powerful control panel.
    -   **Waveform Selection:** Choose between Sine, Triangle, Sawtooth, and Square waves.
    -   **Audio Effects:** Add and control Reverb, Delay, and a Low-Pass Filter in real-time.
-   **Minimalist UI:** A clean, technical interface inspired by the Geist design philosophy, focusing on creativity and interaction.

---

## How It Works

The core of SculptX is its **synesthetic mapping engine**. The app constantly analyzes the geometric properties of the on-screen shape and translates them into audio parameters:

-   **Point Count & Total Length** → **Frequency & Volume**
-   **Rotation** → **Waveform (Timbre)**
-   **Slider Controls** → **Audio Effects (Reverb, Delay, Filter)**

This creates a direct and intuitive link between what you see and what you hear.

---

## Tech Stack

-   **Framework:** Flutter
-   **Audio Engine:** `flutter_soloud` for powerful, low-level audio synthesis.
-   **3D Math:** `vector_math` for all 3D transformations and projections.

---

## Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

-   Flutter SDK: [https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
-   An IDE like Vim or emacs.

### Installation

1.  Clone the repo:
    ```sh
    git clone [https://github.com/your_username/sculptx.git](https://github.com/your_username/sculptx.git)
    ```
2.  Navigate to the project directory:
    ```sh
    cd sculptx
    ```
3.  Install dependencies:
    ```sh
    flutter pub get
    ```
4.  Run the app:
    ```sh
    flutter run
    ```

---

## Future Ideas

SculptX is an ongoing exploration. Future enhancements could include:

-   [ ] Saving and sharing user-created sculptures.
-   [ ] More complex audio effects like distortion and chorus.
-   [ ] Mapping shape color to sound parameters.
-   [ ] MIDI output to control external hardware synthesizers.

---

## License

Distributed under the MIT License. See `LICENSE` for more information.
