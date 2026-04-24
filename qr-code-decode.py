##
## MacOS required:
## brew install zbar
##
## mkdir ~/lib
## ln -s $(brew --prefix zbar)/lib/libzbar.dylib ~/lib/libzbar.dylib
##

from qreader import QReader
import cv2

# Create a QReader instance
qreader = QReader()

# Get the image that contains the QR code
image = cv2.cvtColor(cv2.imread("image.png"), cv2.COLOR_BGR2RGB)

# Use the detect_and_decode function to get the decoded QR data
#decoded_text = qreader.detect_and_decode(image=image)
print(qreader.detect_and_decode(image=image))
