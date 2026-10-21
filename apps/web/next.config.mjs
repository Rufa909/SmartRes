const nextConfig = {
  // Điện thoại chỉ cần truy cập cổng web 3000. Next.js chuyển tiếp các
  // yêu cầu đặt món sang API cục bộ, tránh bị Windows Firewall chặn cổng 4010.
  async rewrites() {
    return [
      {
        source: "/api/customer/:path*",
        destination: "http://127.0.0.1:4010/api/:path*"
      }
    ];
  }
};

export default nextConfig;
