FROM eclipse-temurin:17-jre
WORKDIR /app
COPY target/transfers-service-0.1.0.jar app.jar
EXPOSE 9102
ENTRYPOINT ["java","-jar","/app/app.jar"]