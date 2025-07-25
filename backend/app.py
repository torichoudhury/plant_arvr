from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from PIL import Image
import io
import numpy as np
from ultralytics import YOLO
import base64

app = FastAPI()
model_path = "best.pt"
model = YOLO(model_path)


class ImageBase64(BaseModel):
    image_base64: str


@app.post("/predict/")
async def predict_image(data: ImageBase64):
    try:
        # Decode the base64 image string
        image_data = base64.b64decode(data.image_base64)
        image = Image.open(io.BytesIO(image_data)).convert("RGB")
    except Exception as e:
        raise HTTPException(status_code=400, detail="Invalid base64 string")

    # Convert the image to a NumPy array
    image_np = np.array(image)

    # Run the YOLO model prediction
    results = model.predict(image_np)

    # Extract and print the class names of the predictions
    predicted_classes = []
    for result in results:
        for box in result.boxes:
            class_id = box.cls  # Class index
            class_name = model.names[
                int(class_id)
            ]  # Get class name using model's label map
            predicted_classes.append(class_name)
            print(f"Predicted class: {class_name}")

    # Get the rendered image (bounding boxes, etc.)
    rendered_image = results[0].plot()
    rendered_image_pil = Image.fromarray(rendered_image)

    # Save the rendered image to a BytesIO object
    img_output = io.BytesIO()
    rendered_image_pil.save(img_output, format="JPEG")
    img_output.seek(0)

    # Encode the image to base64
    img_base64 = base64.b64encode(img_output.getvalue()).decode("utf-8")

    # Return the base64-encoded image as JSON along with class names
    return JSONResponse(
        content={"image_base64": img_base64, "predicted_classes": predicted_classes}
    )


@app.post("/predict/file")
async def predict_image_file(file: UploadFile = File(...)):
    try:
        # Read the uploaded file
        contents = await file.read()
        image = Image.open(io.BytesIO(contents)).convert("RGB")
    except Exception as e:
        raise HTTPException(status_code=400, detail="Invalid image file")

    # Convert the image to a NumPy array
    image_np = np.array(image)

    # Run the YOLO model prediction
    results = model.predict(image_np)

    # Extract the class names and confidence scores
    predictions = []
    for result in results:
        if result.boxes is not None:
            for box in result.boxes:
                class_id = int(box.cls)  # Class index
                class_name = model.names[
                    class_id
                ]  # Get class name using model's label map
                confidence = float(box.conf)  # Confidence score
                predictions.append({"plant_name": class_name, "confidence": confidence})
                print(f"Predicted class: {class_name}, Confidence: {confidence:.2f}")

    # Return the prediction with highest confidence, or default if no predictions
    if predictions:
        best_prediction = max(predictions, key=lambda x: x["confidence"])
        return JSONResponse(content=best_prediction)
    else:
        return JSONResponse(content={"plant_name": "Unknown Plant", "confidence": 0.0})


@app.get("/")
def hello_world():
    return "Hello world"


@app.head("/")
def hello_world_head():
    # Respond without a body, but with the same headers as GET
    return JSONResponse(content=None)


# To run the server
if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, port=8000)
