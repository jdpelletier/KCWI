import sys
import time

def sleepdots(seconds):
    i = 0
    while i < seconds:
        i += 1
        sys.stdout.write(".")
        sys.stdout.flush()
        time.sleep(1)

    sys.stdout.write('\n')
