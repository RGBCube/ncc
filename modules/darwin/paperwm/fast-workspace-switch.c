#include <CoreGraphics/CoreGraphics.h>
#include <unistd.h>

#define FLOAT_MIN 1.401298464324817e-45

void workingSpaceSwitch(int direction) {
  double magnitude = direction == 0 ? -2.25 : 2.25;
  double gestureValue = 200.0 * magnitude;

  CGEventRef event1a = CGEventCreate(NULL);
  CGEventSetIntegerValueField(event1a, 0x37, 29);
  CGEventSetIntegerValueField(event1a, 0x29, 33231);

  CGEventRef event1b = CGEventCreate(NULL);
  CGEventSetIntegerValueField(event1b, 0x37, 30);
  CGEventSetIntegerValueField(event1b, 0x6E, 23);
  CGEventSetIntegerValueField(event1b, 0x84, 1);
  CGEventSetIntegerValueField(event1b, 0x86, 1);
  CGEventSetDoubleValueField(event1b, 0x7C, magnitude);

  float magnitudeAsFloat = (float)magnitude;
  int32_t magnitudeAsInt = *(int32_t *)&magnitudeAsFloat;
  CGEventSetIntegerValueField(event1b, 0x87, magnitudeAsInt);

  CGEventSetIntegerValueField(event1b, 0x7B, 1);
  CGEventSetIntegerValueField(event1b, 0xA5, 1);
  CGEventSetDoubleValueField(event1b, 0x77, FLOAT_MIN);
  CGEventSetDoubleValueField(event1b, 0x8B, FLOAT_MIN);
  CGEventSetIntegerValueField(event1b, 0x29, 33231);
  CGEventSetIntegerValueField(event1b, 0x88, 0);

  CGEventPost(kCGHIDEventTap, event1b);
  CGEventPost(kCGHIDEventTap, event1a);

  CFRelease(event1a);
  CFRelease(event1b);

  usleep(15000); // 15ms

  CGEventRef event2a = CGEventCreate(NULL);
  CGEventSetIntegerValueField(event2a, 0x37, 29);
  CGEventSetIntegerValueField(event2a, 0x29, 33231);

  CGEventRef event2b = CGEventCreate(NULL);
  CGEventSetIntegerValueField(event2b, 0x37, 30);
  CGEventSetIntegerValueField(event2b, 0x6E, 23);
  CGEventSetIntegerValueField(event2b, 0x84, 4);
  CGEventSetIntegerValueField(event2b, 0x86, 4);
  CGEventSetDoubleValueField(event2b, 0x7C, magnitude);
  CGEventSetIntegerValueField(event2b, 0x87, magnitudeAsInt);
  CGEventSetIntegerValueField(event2b, 0x7B, 1);
  CGEventSetIntegerValueField(event2b, 0xA5, 1);
  CGEventSetDoubleValueField(event2b, 0x77, FLOAT_MIN);
  CGEventSetDoubleValueField(event2b, 0x8B, FLOAT_MIN);
  CGEventSetIntegerValueField(event2b, 0x29, 33231);
  CGEventSetIntegerValueField(event2b, 0x88, 0);

  CGEventSetDoubleValueField(event2b, 0x81, gestureValue);
  CGEventSetDoubleValueField(event2b, 0x82, gestureValue);

  CGEventPost(kCGHIDEventTap, event2b);
  CGEventPost(kCGHIDEventTap, event2a);

  CFRelease(event2a);
  CFRelease(event2b);
}

int main(int argc, char *argv[]) {
  if (argc != 3) {
    fprintf(stderr, "Usage: %s <left|right> <count>\n", argv[0]);
    return 1;
  }

  int direction;
  if (strcmp(argv[1], "right") == 0) {
    direction = 1;
  } else if (strcmp(argv[1], "left") == 0) {
    direction = 0;
  } else {
    fprintf(stderr, "Invalid direction: %s. Use 'left' or 'right'.\n", argv[1]);
    return 1;
  }

  int count = atoi(argv[2]);
  if (count <= 0) {
    fprintf(stderr, "Invalid count: %s. Must be a positive integer.\n", argv[2]);
    return 1;
  }

  for (int i = 0; i < count; i++) {
    if (i > 0) {
      usleep(50000); // 50ms
    }

    workingSpaceSwitch(direction);
  }

  return 0;
}
