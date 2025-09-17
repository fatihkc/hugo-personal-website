describe('Blog Page', () => {
  beforeEach(() => {
    cy.visit('https://fatihkoc.net/posts/')
  })

  it('should load the blog page successfully', () => {
    cy.url().should('include', '/posts/')
    cy.get('h1').should('contain', 'Blog')
  })

  it('should display blog posts', () => {
    cy.get('article').should('have.length.at.least', 1)
  })

  it('should have clickable post links', () => {
    cy.get('article a').first().should('be.visible')
    cy.get('article a').first().click()
    cy.url().should('include', '/posts/')
  })

  it('should display post titles', () => {
    cy.get('article h2').should('be.visible')
  })

  it('should display post dates', () => {
    cy.get('article time').should('be.visible')
  })
})
