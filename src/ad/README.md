# Ad Service

The Ad service provides advertisement based on context keys. If no context keys
are provided then it returns random ads.

## Building Locally

The Ad service requires JDK 21 and Maven. From the repository root, build it with:

```sh
mvn -f src/ad/pom.xml clean package
```

The generated gRPC classes and an executable, dependency-inclusive JAR are
created under `src/ad/target/`.

To run the Ad Service:

```sh
export AD_PORT=8080
export FEATURE_FLAG_GRPC_SERVICE_ADDR=featureflagservice:50053
java -jar src/ad/target/ad-service.jar
```

## Building Docker

From the root of `opentelemetry-demo`, run:

```sh
docker build --file ./src/ad/Dockerfile ./
```
