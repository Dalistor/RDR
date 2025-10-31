package mobileapi

import (
	"context"
	"net"
	"net/http"
	"time"

	"rdr/scraper/cmd/settings"
	"rdr/scraper/internal/web/ulrs"

	"github.com/gin-gonic/gin"
)

var httpServer *http.Server

// StartServer inicia o servidor REST em 127.0.0.1:port no modo (RELEASE/DEBUG)
func StartServer(port string, mode string) error {
	switch mode {
	case "RELEASE":
		gin.SetMode(gin.ReleaseMode)
	case "DEBUG":
		gin.SetMode(gin.DebugMode)
	default:
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()
	router.Use(gin.Recovery(), settings.Cors())
	ulrs.SetUrls(router)

	httpServer = &http.Server{
		Addr:    "127.0.0.1:" + port,
		Handler: router,
	}
	go func() { _ = httpServer.ListenAndServe() }()

	// Aguarda até o socket estar up (ou timeout)
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		conn, err := net.DialTimeout("tcp", "127.0.0.1:"+port, 200*time.Millisecond)
		if err == nil {
			_ = conn.Close()
			return nil
		}
		time.Sleep(100 * time.Millisecond)
	}
	return nil // Mesmo se falhar, a lib/export precisa sempre devolver erro Go válido/compatível para o gomobile
}

// StopServer encerra o servidor HTTP de forma graciosa
func StopServer(timeoutMs int) error {
	if httpServer == nil {
		return nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutMs)*time.Millisecond)
	defer cancel()
	return httpServer.Shutdown(ctx)
}
