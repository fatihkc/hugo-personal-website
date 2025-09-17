describe('About Page', () => {
  beforeEach(() => {
    cy.visit('https://fatihkoc.net/about/')
  })

  it('should load the about page successfully', () => {
    cy.url().should('include', '/about/')
    cy.get('h1').should('contain', 'About')
  })


  it('should have working internal links', () => {
    cy.get('a[href*="/posts/"]').should('have.length.at.least', 1)
    cy.get('a[href*="/contact/"]').should('be.visible')
  })


  it('should have an image', () => {
    cy.get('img').should('be.visible')
  })
})
