# Stage 1: Build the application
FROM maven:3.9.2-eclipse-temurin-17 AS build
WORKDIR /app

# Copy everything and build in one step
COPY pom.xml .
COPY src ./src

# Build without the go-offline step that's causing issues
RUN mvn clean package -DskipTests -P css

# Stage 2: Package into a lightweight image
FROM eclipse-temurin:17-jdk-alpine
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","app.jar"]
