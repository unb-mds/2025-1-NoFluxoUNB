enum EnvironmentType {
  development,
  production,
}

class Environment {
  static String apiUrl = "http://localhost:3000";
  static String apiParsePdfUrl = "http://localhost:3001";

  static EnvironmentType environmentType = EnvironmentType.development;

  static String getApiUrl() {
    return apiUrl;
  }

  static void setEnvironmentType(EnvironmentType environmentType) {
    Environment.environmentType = environmentType;

    if (environmentType == EnvironmentType.development) {
      apiUrl = "http://localhost:3000";
      apiParsePdfUrl = "http://localhost:3001";
    } else {
      apiUrl = "https://no-fluxo.vercel.app";
      apiParsePdfUrl = "https://no-fluxo.vercel.app";
    }
  }
}
