FROM maven:3.9.9-eclipse-temurin-21 AS builder

WORKDIR /workspace

COPY src/ad/pom.xml ./src/ad/pom.xml
COPY src/ad/pb ./src/ad/pb
COPY src/ad/src ./src/ad/src
RUN mvn -B -f src/ad/pom.xml clean package

#####################################################

FROM eclipse-temurin:21-jre

WORKDIR /usr/src/app

COPY --from=builder /workspace/src/ad/target/ad-service.jar ./ad-service.jar

ENV AD_PORT=9099

ENTRYPOINT ["java", "-jar", "/usr/src/app/ad-service.jar"]

