{
  perSystem =
    { pkgs, ... }:
    {
      packages.fast-workspace-switch = pkgs.callPackage (
        {
          stdenv,
          writeText,
          lib,
        }:
        stdenv.mkDerivation {
          pname = "fast-workspace-switch";
          version = "1.0.0";

          src = writeText "fast-workspace-switch.c" /* c */ ''
            #include <CoreGraphics/CoreGraphics.h>
            #include <errno.h>
            #include <inttypes.h>
            #include <stdbool.h>
            #include <stdint.h>
            #include <stdio.h>
            #include <stdlib.h>
            #include <string.h>
            #include <unistd.h>

            static const useconds_t GESTURE_HOLD_MICROS = 15000;
            static const useconds_t INTER_SWITCH_DELAY_MICROS = 50000;
            static const double FLOAT_MIN_VALUE = 1.401298464324817e-45;
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

            typedef struct {
              double magnitude;
              int32_t magnitudeAsInt;
              double gestureValue;
            } SwipeValues;

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

            static SwipeValues swipeValuesForDirection(Direction direction) {
              SwipeValues values;
              values.magnitude = direction == DIRECTION_LEFT ? -2.25 : 2.25;
              values.gestureValue = 200.0 * values.magnitude;

              float magnitudeAsFloat = (float)values.magnitude;
              memcpy(&values.magnitudeAsInt, &magnitudeAsFloat, sizeof(values.magnitudeAsInt));

              return values;
            }

            static CGEventRef createSwipeEvent(const SwipeValues *values, GesturePhase phase) {
              CGEventRef event = CGEventCreate(NULL);
              if (event == NULL) {
                return NULL;
              }

              CGEventSetIntegerValueField(event, 0x37, 30);
              CGEventSetIntegerValueField(event, 0x6E, 23);
              CGEventSetIntegerValueField(event, 0x84, phase);
              CGEventSetIntegerValueField(event, 0x86, phase);
              CGEventSetDoubleValueField(event, 0x7C, values->magnitude);
              CGEventSetIntegerValueField(event, 0x87, values->magnitudeAsInt);
              CGEventSetIntegerValueField(event, 0x7B, 1);
              CGEventSetIntegerValueField(event, 0xA5, 1);
              CGEventSetDoubleValueField(event, 0x77, FLOAT_MIN_VALUE);
              CGEventSetDoubleValueField(event, 0x8B, FLOAT_MIN_VALUE);
              CGEventSetIntegerValueField(event, 0x29, 33231);
              CGEventSetIntegerValueField(event, 0x88, 0);

              if (phase == GESTURE_PHASE_ENDED) {
                CGEventSetDoubleValueField(event, 0x81, values->gestureValue);
                CGEventSetDoubleValueField(event, 0x82, values->gestureValue);
              }

              return event;
            }

            static bool postSwipe(Direction direction) {
              SwipeValues values = swipeValuesForDirection(direction);
              CGEventRef beginMarkerEvent = createMarkerEvent();
              CGEventRef beginSwipeEvent = createSwipeEvent(&values, GESTURE_PHASE_BEGAN);
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
              CGEventRef endSwipeEvent = createSwipeEvent(&values, GESTURE_PHASE_ENDED);
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
