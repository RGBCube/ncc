{
  perSystem =
    { pkgs, ... }:
    {
      packages.fast-workspace-switch = pkgs.callPackage (
        { stdenv, writeText, lib }:
        stdenv.mkDerivation {
          pname = "fast-workspace-switch";
          version = "1.0.0";

          src = writeText "fast-workspace-switch.c" /* c */ ''
            #include <CoreGraphics/CoreGraphics.h>
            #include <errno.h>
            #include <stdbool.h>
            #include <inttypes.h>
            #include <stdint.h>
            #include <stdio.h>
            #include <stdlib.h>
            #include <string.h>
            #include <unistd.h>

            static const useconds_t GESTURE_HOLD_MICROS = 15000;
            static const useconds_t INTER_SWITCH_DELAY_MICROS = 50000;
            static const CGFloat FLOAT_MIN_VALUE = 0x1p-149f;
            static const int64_t SWIPE_MAGNITUDE_CENTI = 225;
            static const uint64_t SWIPE_MAGNITUDE_SCALE = 100;
            static const int64_t SWIPE_GESTURE_VALUE_MULTIPLIER = 200;
            static const int64_t SWIPE_MAGNITUDE_RIGHT_BITS = 1074790400;
            static const int64_t SWIPE_MAGNITUDE_LEFT_BITS = -1072693248;
            static const int32_t EXIT_STATUS_SUCCESS = 0;
            static const int32_t EXIT_STATUS_FAILURE = 1;

            typedef enum {
              GESTURE_PHASE_BEGAN = 1,
              GESTURE_PHASE_ENDED = 4,
            } GesturePhase;

            typedef enum {
              DIRECTION_LEFT,
              DIRECTION_RIGHT,
            } Direction;

            static bool parseCount(const char *value, uint64_t *count) {
              errno = 0;
              char *end = NULL;
              uintmax_t parsed = strtoumax(value, &end, 10);

              if (errno != 0 || end == value || *end != '\0' || parsed == 0 || parsed > UINT64_MAX) {
                return false;
              }

              *count = (uint64_t)parsed;
              return true;
            }

            static CGEventRef createMarkerEvent(void) {
              CGEventRef event = CGEventCreate(NULL);
              if (event == NULL) {
                return NULL;
              }

              CGEventSetIntegerValueField(event, 0x37, 29);
              CGEventSetIntegerValueField(event, 0x29, 33231);
              return event;
            }

            static CGEventRef createSwipeEvent(Direction direction, GesturePhase phase) {
              CGEventRef event = CGEventCreate(NULL);
              if (event == NULL) {
                return NULL;
              }

              const int64_t magnitudeCenti = direction == DIRECTION_LEFT ? -SWIPE_MAGNITUDE_CENTI : SWIPE_MAGNITUDE_CENTI;
              const int64_t magnitudeBits = direction == DIRECTION_LEFT ? SWIPE_MAGNITUDE_LEFT_BITS : SWIPE_MAGNITUDE_RIGHT_BITS;
              const int64_t gestureValue = magnitudeCenti * SWIPE_GESTURE_VALUE_MULTIPLIER / (int64_t)SWIPE_MAGNITUDE_SCALE;

              CGEventSetIntegerValueField(event, 0x37, 30);
              CGEventSetIntegerValueField(event, 0x6E, 23);
              CGEventSetIntegerValueField(event, 0x84, phase);
              CGEventSetIntegerValueField(event, 0x86, phase);
              CGEventSetDoubleValueField(event, 0x7C, (CGFloat)magnitudeCenti / (CGFloat)SWIPE_MAGNITUDE_SCALE);
              CGEventSetIntegerValueField(event, 0x87, magnitudeBits);
              CGEventSetIntegerValueField(event, 0x7B, 1);
              CGEventSetIntegerValueField(event, 0xA5, 1);
              CGEventSetDoubleValueField(event, 0x77, FLOAT_MIN_VALUE);
              CGEventSetDoubleValueField(event, 0x8B, FLOAT_MIN_VALUE);
              CGEventSetIntegerValueField(event, 0x29, 33231);
              CGEventSetIntegerValueField(event, 0x88, 0);

              if (phase == GESTURE_PHASE_ENDED) {
                CGEventSetDoubleValueField(event, 0x81, (CGFloat)gestureValue);
                CGEventSetDoubleValueField(event, 0x82, (CGFloat)gestureValue);
              }

              return event;
            }

            static bool postSwipe(Direction direction) {
              CGEventRef beginMarkerEvent = createMarkerEvent();
              CGEventRef beginSwipeEvent = createSwipeEvent(direction, GESTURE_PHASE_BEGAN);
              if (beginMarkerEvent == NULL || beginSwipeEvent == NULL) {
                fprintf(stderr, "Failed to create begin events.\n");
                if (beginMarkerEvent != NULL) {
                  CFRelease(beginMarkerEvent);
                }
                if (beginSwipeEvent != NULL) {
                  CFRelease(beginSwipeEvent);
                }
                return false;
              }

              CGEventPost(kCGHIDEventTap, beginSwipeEvent);
              CGEventPost(kCGHIDEventTap, beginMarkerEvent);

              CFRelease(beginMarkerEvent);
              CFRelease(beginSwipeEvent);

              usleep(GESTURE_HOLD_MICROS);

              CGEventRef endMarkerEvent = createMarkerEvent();
              CGEventRef endSwipeEvent = createSwipeEvent(direction, GESTURE_PHASE_ENDED);
              if (endMarkerEvent == NULL || endSwipeEvent == NULL) {
                fprintf(stderr, "Failed to create end events.\n");
                if (endMarkerEvent != NULL) {
                  CFRelease(endMarkerEvent);
                }
                if (endSwipeEvent != NULL) {
                  CFRelease(endSwipeEvent);
                }
                return false;
              }

              CGEventPost(kCGHIDEventTap, endSwipeEvent);
              CGEventPost(kCGHIDEventTap, endMarkerEvent);

              CFRelease(endMarkerEvent);
              CFRelease(endSwipeEvent);

              return true;
            }

            int32_t main(int32_t argc, char *argv[]) {
              if (argc != 3) {
                fprintf(stderr, "Usage: %s <left|right> <count>\n", argv[0]);
                return EXIT_STATUS_FAILURE;
              }

              Direction direction;
              if (strcmp(argv[1], "right") == 0) {
                direction = DIRECTION_RIGHT;
              } else if (strcmp(argv[1], "left") == 0) {
                direction = DIRECTION_LEFT;
              } else {
                fprintf(stderr, "Invalid direction: %s. Use 'left' or 'right'.\n", argv[1]);
                return EXIT_STATUS_FAILURE;
              }

              uint64_t count = 0;
              if (!parseCount(argv[2], &count)) {
                fprintf(stderr, "Invalid count: %s. Must be a positive integer.\n", argv[2]);
                return EXIT_STATUS_FAILURE;
              }

              for (uint64_t i = 0; i < count; i++) {
                if (i > 0) {
                  usleep(INTER_SWITCH_DELAY_MICROS);
                }

                if (!postSwipe(direction)) {
                  return EXIT_STATUS_FAILURE;
                }
              }

              return EXIT_STATUS_SUCCESS;
            }
          '';

          dontUnpack = true;
          dontConfigure = true;

          buildPhase = /* bash */ ''
            $CC -O2 -Wall -Wextra \
              -framework CoreGraphics \
              -framework CoreFoundation \
              -o fast-workspace-switch $src
          '';

          installPhase = /* bash */ ''
            mkdir -p $out/bin
            install -m755 fast-workspace-switch $out/bin/
          '';

          meta = {
            description = "Fast workspace switcher for Darwin";
            platforms = lib.platforms.darwin;
            mainProgram = "fast-workspace-switch";
          };
        }
      ) { };
    };
}
