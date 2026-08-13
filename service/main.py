"""Safe placeholder for the future ICICI Breeze trading service."""

import logging
import signal
import time

running = True


def stop(_signum, _frame):
    global running
    running = False


signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
logging.basicConfig(level=logging.INFO)
logging.info("Breeze service placeholder started; no trading logic is configured")
while running:
    time.sleep(30)
logging.info("Breeze service placeholder stopped")
