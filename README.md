🌸 Fiore
Fiore is a dynamic social platform designed to help you organize and discover on-the-go events with people nearby. Built with a robust FastAPI backend and a sleek Flutter frontend, Fiore aims to bring communities together effortlessly.

🔗 Live Demo: fiorejoy.com

🚀 Tech Stack
Frontend: Flutter

Backend: FastAPI

Database: PostgreSQL

🛠️ Getting Started
1. Clone the Repository

git clone https://github.com/FioreJoy/fiore.git
cd fiore
2. Backend Setup
Navigate to the backend directory and set up the Python environment:


cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
Configure the Database
Ensure PostgreSQL is installed and running. Then, create the database and user:


sudo -u postgres psql
Inside the PostgreSQL shell:

sql
Copy
Edit
CREATE DATABASE fiore;
CREATE USER fiore_user WITH ENCRYPTED PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE fiore TO fiore_user;
ALTER ROLE fiore_user SUPERUSER;
\q
Create a .env file in the backend/ directory with the following content:

env
Copy
Edit
DB_USER=fiore_user
DB_PASSWORD=your_password
DB_NAME=fiore
DB_HOST=localhost
DB_PORT=5432

JWT_SECRET=your_secret_key
Apply the database schema:


psql -U fiore_user -d fiore -f schema.sql
Start the FastAPI server:


uvicorn main:app --reload
Access the API documentation at http://127.0.0.1:8000/docs.

3. Frontend Setup
Navigate to the frontend directory and set up Flutter:


cd ../frontend
flutter pub get
Run the Flutter web application:


flutter run -d web-server --web-port 9339
Visit http://127.0.0.1:9339 to view the app in your browser.

✅ Testing the Setup
API Documentation: http://127.0.0.1:8000/docs

Frontend Application: http://127.0.0.1:9339

🤝 Contributing
We welcome contributions! If you'd like to improve Fiore, please fork the repository and submit a pull request.

🌟 Future Enhancements
Docker support for streamlined deployment

Enhanced user authentication mechanisms

Mobile application integration

📄 License
This project is licensed under the MIT License.
