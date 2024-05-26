package main

import (
	"database/sql"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"time"

	"github.com/brianvoe/gofakeit"
	_ "github.com/lib/pq"
)

var Version string

func main() {
	log.Printf("starting server version: %s\n", Version)

	db := newPostgres()
	handler := Handler{db: db}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", handler.Home)
	mux.HandleFunc("GET /health/{$}", handler.Health)

	if err := http.ListenAndServe(net.JoinHostPort("", "8080"), mux); err != nil {
		log.Fatalf("error starting server: %s", err)
	}
}

type Handler struct {
	db *sql.DB
}

func (h Handler) Home(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "request thise time: %s, (%s)", time.Now().Format(time.RFC3339), gofakeit.FirstName())
}

func (h Handler) Health(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "ok")
}

func newPostgres() *sql.DB {
	dsn := fmt.Sprintf(
		"dbname=%s user=%s password=%s host=%s port=%s sslmode=disable",
		os.Getenv("PG_DB"),
		os.Getenv("PG_USER"),
		os.Getenv("PG_PASSWORD"),
		os.Getenv("PG_HOST"),
		os.Getenv("PG_PORT"),
	)
	connect, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalln(err)
	}

	if err := connect.Ping(); err != nil {
		log.Fatalln(err)
	}

	log.Println("start postgres")

	return connect
}
